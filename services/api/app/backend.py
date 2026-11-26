import os

from .accounts import Accounts, policies_from_env
from .admin_content import AdminContent
from .admin_import import AdminImport
from .cnn import HandwritingCnn, Model, model_from_env
from .conversation import ConversationJobs, conversation_models
from .deletions import Deletions
from .errors import ApiError
from .exams import Exams
from .feedback import Feedback
from .ocr_backend import OcrService
from .ocr_providers import pinned_models_from_env
from .ports import Access, Call, Identity, Result, UnconfiguredBackend
from .postgres import Database, one
from .progress import Progress
from .reviews import Reviews
from .roleplay import Roleplay
from .storage import LEARNING_BUCKET, ImageStorage, SupabaseImageStorage
from .tts import SpeechProvider, Tts, speech_from_env
from .vocabulary import Vocabulary
from .writing import Writing


class PostgresBackend(UnconfiguredBackend):
    def __init__(
        self,
        db: Database,
        storage: ImageStorage,
        models: dict[str, str] | None = None,
        *,
        policies: dict | None = None,
        learning_storage: ImageStorage | None = None,
        cnn_model: Model | None = None,
        speech_provider: SpeechProvider | None = None,
        deletion_enabled: bool = False,
        live_conversation_models: dict | None = None,
    ):
        self.ready = bool(
            policies
            and models
            and learning_storage
            and cnn_model
            and speech_provider
            and deletion_enabled
            and (live_conversation_models or {}).keys()
            >= {"transcription", "turn", "turn_audio"}
        )
        self.db = db
        self.accounts = Accounts(db, policies)
        self.vocabulary = Vocabulary(db, self.accounts)
        self.reviews = Reviews(db, self.accounts, self.vocabulary)
        self.progress = Progress(db, self.accounts)
        self.exams = Exams(db, self.accounts)
        self.feedback = Feedback(db, self.accounts)
        self.admin = AdminContent(db, self.accounts)
        self.learning_storage = learning_storage
        self.admin_import = AdminImport(db, self.accounts, learning_storage)
        self.cnn = HandwritingCnn(db, self.accounts, cnn_model)
        self.writing = Writing(db, self.accounts, learning_storage, self.cnn)
        self.roleplay = Roleplay(db, self.accounts)
        self.conversation = ConversationJobs(
            db, self.accounts, self.roleplay, storage, live_conversation_models
        )
        self.deletions = Deletions(db, self.accounts, deletion_enabled)
        self.tts = Tts(db, self.accounts, learning_storage, speech_provider)
        self.ocr = OcrService(
            db, self.accounts, storage, models or {}, learning_storage
        )
        self._handlers = self._operation_handlers()

    async def healthy(self) -> bool:
        if not self.ready:
            return False
        try:
            async with self.db.transaction(receipt=True) as tx:
                model = await self.cnn.published(tx)
                migration = await one(
                    tx,
                    "SELECT to_regprocedure('app_private.ocr_lexicon()') IS NOT NULL AS ready",
                )
                return model is not None and migration["ready"]
        except ApiError:
            return False

    async def access(self, identity: Identity) -> Access:
        return await self.accounts.access(identity)

    async def deletion_status(self, token: str) -> Result:
        return await self.deletions.status(token)

    def _operation_handlers(self):
        return {
            "listVocabulary": self.vocabulary.words,
            "getVocabulary": self.vocabulary.word,
            "listLearningItems": self.vocabulary.items,
            "getLearningItem": self.vocabulary.item,
            "saveLearningItem": self.vocabulary.save,
            "changeItemState": self.vocabulary.state,
            "listNotes": self.vocabulary.notes,
            "createNote": self.vocabulary.create_note,
            "editNote": self.vocabulary.edit_note,
            "deleteNote": self.vocabulary.delete_note,
            "selectDefaultNote": self.vocabulary.default_note,
            "reviewQueue": self.vocabulary.queue,
            "startReview": self.reviews.start,
            "getReview": self.reviews.get,
            "changeReviewState": self.reviews.state,
            "revealCard": self.reviews.reveal,
            "rateCard": self.reviews.rate,
            "listTests": self.exams.tests,
            "startTest": self.exams.start,
            "listAttempts": self.exams.attempts,
            "getAttempt": self.exams.get,
            "saveAnswer": self.exams.answer,
            "submitTest": self.exams.submit,
            "getTestResult": self.exams.result,
            "getDashboard": self.progress.dashboard,
            "listActivities": self.progress.activities,
            "updateMe": self.accounts.update,
            "updateAvatar": self.ocr.update_avatar,
            "requestDeletion": self.deletions.request,
            "resolveSample": self.vocabulary.resolve_sample,
            "editPersonalEntry": self.vocabulary.edit_personal,
            "linkPersonalEntry": self.vocabulary.link_personal,
            "deleteScan": self.ocr.delete_scan,
            "deletePrivateMedia": self.ocr.delete_media,
            "createFeedback": self.feedback.create,
            "listOwnFeedback": self.feedback.list,
            "getOwnFeedback": self.feedback.get,
            "adminListReports": self.feedback.list,
            "adminGetReport": self.feedback.get,
            "adminUpdateReport": self.feedback.update,
            "uploadLearningMedia": self.admin_import.upload,
            "startImport": self.admin_import.start,
            "getImport": self.admin_import.get,
            "mapImport": self.admin_import.map,
            "validateImport": self.admin_import.validate,
            "getImportRows": self.admin_import.rows,
            "confirmImport": self.admin_import.confirm,
            "adminListWords": self.admin.words,
            "adminGetWord": self.admin.get_word,
            "adminCreateWord": self.admin.revise_word,
            "adminReviseWord": self.admin.revise_word,
            "adminListTests": self.admin.tests,
            "adminGetTest": self.admin.get_test,
            "adminReviseTest": self.admin.revise_test,
            "adminListQuestions": self.admin.questions,
            "adminGetQuestion": self.admin.get_question,
            "transitionContent": self.admin.transition,
            "listScenarios": self.admin.scenarios,
            "startRoleplay": self.roleplay.start,
            "listRoleplay": self.roleplay.list,
            "getRoleplay": self.roleplay.get,
            "deleteRoleplay": self.roleplay.end_or_delete,
            "endRoleplay": self.roleplay.end_or_delete,
            "createTextDraft": self.roleplay.write_draft,
            "confirmDraft": self.roleplay.write_draft,
            "getDraft": self.roleplay.draft,
            "transcribeAudio": self.conversation.create,
            "submitTurn": self.conversation.create,
            "retryTurnAudio": self.conversation.create,
            "getScenario": self.admin.scenarios,
            "adminListScenarios": self.admin.scenarios,
            "adminGetScenario": self.admin.scenarios,
            "adminReviseScenario": self.admin.revise_scenario,
            "listCharacters": self.writing.characters,
            "strokeData": self.writing.strokes,
            "saveQuiz": self.writing.quiz,
            "predictCharacter": self.cnn.predict,
            "confirmCharacter": self.cnn.confirm,
            "ttsContent": self.tts.content,
            "getMe": self.accounts.get_me,
            "currentPolicies": self.accounts.policies,
            "bootstrapMe": self.accounts.bootstrap,
            "getConsents": self.accounts.list_consents,
            "recordConsent": self.accounts.record_consent,
            "createOcrJob": self.ocr.create,
            "listScans": self.ocr.list_scans,
            "getScan": self.ocr.get_scan,
            "editScan": self.ocr.edit_scan,
            "listScanTokens": self.ocr.list_scan_tokens,
            "listJobs": self.ocr.list_jobs,
            "getJob": self.ocr.get_job,
            "cancelJob": self.ocr.cancel,
            "getMediaUrl": self.ocr.sign_media,
        }

    async def execute(self, call: Call) -> Result:
        handler = self._handlers.get(call.operation)
        if handler is None:
            return await super().execute(call)
        return await handler(call)


def postgres_backend_from_env() -> PostgresBackend | UnconfiguredBackend:
    dsn = os.getenv("HANYU_DATABASE_URL", "").strip()
    if not dsn:
        return UnconfiguredBackend()
    url, storage, key, terms = [
        os.getenv(name, "").strip()
        for name in (
            "SUPABASE_URL",
            "SUPABASE_STORAGE_KEY",
            "HANYU_SIGNING_KEY",
            "HANYU_TERMS_VERSION",
        )
    ]
    if not (url and storage and len(key.encode()) >= 32 and terms):
        raise ValueError(
            "PostgreSQL backend requires the Supabase URL, Storage key, a signing key of at least 32 bytes and current terms version"
        )
    return PostgresBackend(
        Database(dsn, key.encode(), terms),
        SupabaseImageStorage(url, storage),
        pinned_models_from_env(),
        policies=policies_from_env(terms),
        learning_storage=SupabaseImageStorage(url, storage, bucket=LEARNING_BUCKET),
        cnn_model=model_from_env(),
        speech_provider=speech_from_env(),
        deletion_enabled=os.getenv("HANYU_DELETION_ENABLED") == "1",
        live_conversation_models=conversation_models(),
    )

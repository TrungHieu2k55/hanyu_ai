import 'package:doanchuyennganh2/features/roleplay/domain/scenario.dart';

const sampleScenarios = [
  Scenario(
    'tourism',
    'Đón khách tại Đà Nẵng',
    'Nhân viên đón khách',
    'Khách Trung Quốc',
    'Chào khách và hỏi kế hoạch tham quan.',
    [
      '你好！我想去海边。',
      'Nǐ hǎo! Wǒ xiǎng qù hǎibiān.',
      'Xin chào! Tôi muốn đến bờ biển.',
    ],
    [
      '谢谢！我们怎么去？',
      'Xièxie! Wǒmen zěnme qù?',
      'Cảm ơn! Chúng ta đi bằng cách nào?',
    ],
    '你好！欢迎来到岘港。',
  ),
  Scenario(
    'directions',
    'Hỏi đường',
    'Người đang tìm đường',
    'Người dân địa phương',
    'Hỏi vị trí nhà ga và cách đi.',
    ['你好，你想去哪里？', 'Nǐ hǎo, nǐ xiǎng qù nǎlǐ?', 'Xin chào, bạn muốn đi đâu?'],
    ['车站在前面。', 'Chēzhàn zài qiánmiàn.', 'Nhà ga ở phía trước.'],
    '请问，车站在哪里？',
  ),
  Scenario(
    'shopping',
    'Mua hàng Taobao',
    'Người mua hàng',
    'Người bán hàng',
    'Hỏi giá và trao đổi lựa chọn sản phẩm.',
    ['你好！你想买什么？', 'Nǐ hǎo! Nǐ xiǎng mǎi shénme?', 'Xin chào! Bạn muốn mua gì?'],
    ['这个一百元。', 'Zhège yìbǎi yuán.', 'Cái này một trăm tệ.'],
    '这个多少钱？',
  ),
  Scenario(
    'business',
    'Giao tiếp thương mại',
    'Đại diện doanh nghiệp Việt Nam',
    'Đối tác Trung Quốc',
    'Giới thiệu doanh nghiệp và trao đổi mong muốn hợp tác.',
    ['很高兴认识你。', 'Hěn gāoxìng rènshi nǐ.', 'Rất vui được làm quen với bạn.'],
    [
      '希望我们合作愉快。',
      'Xīwàng wǒmen hézuò yúkuài.',
      'Hy vọng chúng ta hợp tác vui vẻ.',
    ],
    '你好！我们想和你们合作。',
  ),
];

import '../models/message_template_model.dart';

/// Offline fallback for the admin-managed message library.
///
/// The live templates come from `GET /message-templates` and are edited in the
/// Admin Dashboard; this list is the spec's initial seed (§12, §13) and is only
/// shown when that request fails, so the member can still send something.
class MessageTemplateSeed {
  const MessageTemplateSeed._();

  static List<MessageTemplate> forType(String type) =>
      type == MessageTemplateType.proposal ? proposal : interest;

  static List<MessageTemplate> _build(String type, List<List<String>> rows) {
    return <MessageTemplate>[
      for (int i = 0; i < rows.length; i++)
        MessageTemplate(
          id: 'seed-$type-${i + 1}',
          type: type,
          title: rows[i][0],
          opening: rows[i][1],
          body: rows[i][2],
          closing: rows[i][3],
          displayOrder: i + 1,
        ),
    ];
  }

  static final List<MessageTemplate> interest = _build(MessageTemplateType.interest, <List<String>>[
    <String>[
      'Simple & Sincere',
      'Your profile caught my attention.',
      'I would be happy to connect and learn more about you.',
      'Looking forward to a positive connection.',
    ],
    <String>[
      'Meaningful Connection',
      'Some connections are worth exploring.',
      'Your profile seems interesting, and I would like to take the first step toward getting to know you.',
      'Wishing you a wonderful day.',
    ],
    <String>[
      'Respectful Interest',
      'I came across your profile and found it interesting.',
      'I would appreciate the opportunity to connect if you feel the same.',
      'With respect and best wishes.',
    ],
    <String>[
      'A Thoughtful Beginning',
      'Every meaningful journey begins with a small step.',
      'I would like to express my interest in your profile and see where this connection may lead.',
      'May this be the start of something meaningful.',
    ],
    <String>[
      'Values & Compatibility',
      'A strong connection often begins with shared values.',
      'Your profile encouraged me to reach out and explore the possibility of compatibility.',
      'Wishing you the best in your search.',
    ],
    <String>[
      'Warm & Friendly',
      'Your profile left a positive impression on me.',
      'I would love the opportunity to connect and learn more about your interests and expectations.',
      'Hope we get the chance to connect.',
    ],
    <String>[
      'Serious Intentions',
      'I am here with sincere intentions of finding a life partner.',
      'Your profile caught my attention, and I would like to explore whether we may be compatible.',
      'Thank you for considering my interest.',
    ],
    <String>[
      'A New Possibility',
      'Sometimes, a promising future starts with a simple introduction.',
      'I would like to connect with you and see whether our expectations align.',
      'Wishing you happiness and clarity in your search.',
    ],
    <String>[
      'Elegant & Concise',
      'I found your profile worth getting to know.',
      'I would be glad to connect and explore a potential match.',
      'Best wishes for your journey ahead.',
    ],
    <String>[
      'Compatibility First',
      'Finding the right partner starts with understanding one another.',
      'I would welcome the chance to learn about your values and what you seek in a life partner.',
      'I hope we find common ground.',
    ],
    <String>[
      'Positive First Step',
      'Your profile stood out to me in a positive way.',
      'I would like to express my interest and give us an opportunity to connect.',
      "Here's to the possibility of a meaningful connection.",
    ],
    <String>[
      'Honest & Direct',
      'I would like to get to know you with genuine intentions.',
      'Your profile seems aligned with what I am looking for in a potential life partner.',
      'I would be pleased if you considered connecting.',
    ],
    <String>[
      'Future-Focused',
      'A lasting relationship begins with mutual understanding.',
      'I am interested in learning more about you and exploring the possibility of building a future together.',
      'Wishing you success in finding the right match.',
    ],
    <String>[
      'Gentle & Respectful',
      'I hope you are having a pleasant day.',
      'I came across your profile and would appreciate the opportunity to connect, if you are comfortable.',
      'Thank you for your time and consideration.',
    ],
    <String>[
      'Purposeful Connection',
      'I believe the right connection begins with sincerity and respect.',
      'I would like to express my interest in your profile and see if we could be a good match.',
      'May your search lead you to the right person.',
    ],
  ]);

  static final List<MessageTemplate> proposal = _build(MessageTemplateType.proposal, <List<String>>[
    <String>[
      'Sincere Marriage Intention',
      'I believe a strong marriage begins with sincerity, trust, and mutual respect.',
      'After reviewing your profile, I would like to express my genuine interest in exploring a future together, should our values and expectations align.',
      'I would welcome the opportunity to take this step forward together.',
    ],
    <String>[
      'Building a Future Together',
      'A meaningful partnership is built on understanding, commitment, and shared goals.',
      'I am interested in getting to know you with the intention of exploring a serious relationship that may lead to marriage.',
      'I hope we can discuss this possibility with openness and respect.',
    ],
    <String>[
      'Values & Understanding',
      'I believe compatibility goes beyond a profile; it grows through shared values and understanding.',
      'Your profile has encouraged me to consider the possibility of a meaningful partnership, and I would like to explore our compatibility more seriously.',
      'I would be glad to hear your thoughts when you feel comfortable.',
    ],
    <String>[
      'A Thoughtful Next Step',
      'Every lasting commitment begins with an honest conversation.',
      'I would like to take our connection to the next stage and explore whether we may be suitable life partners.',
      'If you share this intention, we can discuss the next steps together.',
    ],
    <String>[
      'Respectful Proposal',
      'With respect for your choices and expectations, I would like to share my intention.',
      'I am interested in exploring a marriage-oriented connection with you and understanding whether our long-term goals are compatible.',
      'Thank you for considering this proposal thoughtfully.',
    ],
    <String>[
      'Family-Oriented Future',
      'A life partnership is not only about two people, but also about building trust between families.',
      'If we find compatibility, I would be happy to discuss a family introduction and the possibility of taking this connection forward toward marriage.',
      'I hope we can approach the next steps with mutual understanding.',
    ],
    <String>[
      'Commitment & Clarity',
      'I value clarity of intention when it comes to choosing a life partner.',
      'My intention is to explore a serious, respectful connection that could lead to marriage if we both feel compatible.',
      'I welcome an honest conversation about our expectations.',
    ],
    <String>[
      'A Partnership of Respect',
      'I believe a happy marriage grows through kindness, patience, and mutual respect.',
      'I would like to explore whether we share the values and outlook needed to build a supportive life together.',
      'It would be a privilege to learn more about your perspective.',
    ],
    <String>[
      'Long-Term Compatibility',
      'Choosing a life partner is an important decision that deserves care and understanding.',
      'I would like us to discuss our priorities, expectations, and future goals to determine whether we could be a suitable match.',
      'I look forward to hearing your thoughts whenever you are ready.',
    ],
    <String>[
      'Honest & Purposeful',
      'I would like to approach this connection with honesty and clear intentions.',
      'I am interested in exploring the possibility of marriage and understanding whether we are aligned in our values, lifestyle, and future plans.',
      'If you are comfortable, we can take the next step at a pace that suits us both.',
    ],
    <String>[
      'A Shared Journey',
      'The right partnership is one in which both people feel heard, respected, and supported.',
      'I would be pleased to explore whether we could build that kind of partnership together, with marriage as the intended goal if we are compatible.',
      'I hope we can begin this discussion with an open mind.',
    ],
    <String>[
      'Maturity & Mutual Choice',
      'I believe an important decision like marriage should be made with maturity and mutual consent.',
      'I would like to share my sincere intention to explore a future together while giving both of us the space to understand our compatibility.',
      'Your comfort and honest response are important to me.',
    ],
    <String>[
      'Trust & Stability',
      'Trust, responsibility, and understanding are qualities I value in a lasting relationship.',
      'I would like to explore whether our expectations for married life are compatible and whether we can move forward with confidence.',
      'I would welcome a thoughtful conversation about our future goals.',
    ],
    <String>[
      'Open Conversation',
      'A good decision begins with an open and respectful conversation.',
      'I would like to discuss our expectations for marriage, family involvement, and the kind of future we hope to build.',
      'If you are willing, we can decide the next steps together.',
    ],
    <String>[
      'A Meaningful Commitment',
      'I see marriage as a meaningful commitment grounded in respect, trust, and shared responsibility.',
      'With that intention, I would like to explore the possibility of becoming life partners, provided we both feel that this is the right match.',
      'Thank you for considering this step; I respect whatever decision feels right for you.',
    ],
  ]);
}

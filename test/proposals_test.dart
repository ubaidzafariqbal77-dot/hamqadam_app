import 'package:flutter_test/flutter_test.dart';
import 'package:hamqadam/models/proposal_model.dart';

void main() {
  group('ProposalModel Tests', () {
    test('parses ProposalPage from GET /proposals JSON correctly', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'data': <dynamic>[
          <String, dynamic>{
            'id': 24,
            'status': 'accepted',
            'status_value': 1,
            'initial_note': 'Assalamualaikum, please review our proposal.',
            'compatibility_percentage': 85,
            'sender': <String, dynamic>{
              'id': 19,
              'code': '20260819',
              'name': 'Ali Khan',
              'photo': 'https://hamqadam.com/uploads/photo1.jpg',
              'membership': 1,
              'approved': true,
            },
            'recipient': <String, dynamic>{
              'id': 66,
              'code': '20260866',
              'name': 'Younis Gopang',
              'photo': 'https://hamqadam.com/uploads/photo2.jpg',
              'membership': 1,
              'approved': true,
            },
            'created_at': '2026-08-27T06:43:03.000000Z',
            'updated_at': '2026-08-27T06:43:26.000000Z',
          },
          <String, dynamic>{
            'id': 23,
            'status': 'pending',
            'status_value': 0,
            'initial_note': null,
            'compatibility_percentage': null,
            'sender': <String, dynamic>{
              'id': 66,
              'code': '20260866',
              'name': 'Younis Gopang',
              'photo': null,
              'membership': 1,
              'approved': true,
            },
            'recipient': <String, dynamic>{
              'id': 5,
              'code': 'DEMO45148DAE',
              'name': 'Ayesha Khan',
              'photo': null,
              'membership': 1,
              'approved': true,
            },
            'created_at': '2026-08-25T18:52:52.000000Z',
            'updated_at': '2026-08-25T18:52:52.000000Z',
          }
        ],
        'meta': <String, dynamic>{
          'current_page': 1,
          'from': 1,
          'last_page': 1,
          'per_page': 20,
          'to': 2,
          'total': 2,
        },
        'success': true,
      };

      final ProposalPage page = ProposalPage.fromJson(json);

      expect(page.proposals.length, 2);
      expect(page.currentPage, 1);
      expect(page.lastPage, 1);
      expect(page.total, 2);
      expect(page.hasMore, false);

      final ProposalModel first = page.proposals.first;
      expect(first.id, 24);
      expect(first.status, 'accepted');
      expect(first.isAccepted, true);
      expect(first.isPending, false);
      expect(first.statusLabel, 'Accepted');
      expect(first.initialNote, 'Assalamualaikum, please review our proposal.');
      expect(first.compatibilityPercentage, 85);
      expect(first.sender?.name, 'Ali Khan');
      expect(first.recipient?.name, 'Younis Gopang');

      // Relative getters check with currentUserId = 66 (Younis)
      expect(first.isReceivedBy(66), true);
      expect(first.isSentBy(66), false);
      expect(first.otherParty(66)?.name, 'Ali Khan');

      final ProposalModel second = page.proposals.last;
      expect(second.id, 23);
      expect(second.status, 'pending');
      expect(second.isPending, true);
      expect(second.statusLabel, 'Pending');
      expect(second.isSentBy(66), true);
      expect(second.isReceivedBy(66), false);
      expect(second.otherParty(66)?.name, 'Ayesha Khan');
    });

    test('verifies status mapping and helpers on ProposalModel', () {
      const ProposalModel pending = ProposalModel(id: 1, status: 'pending');
      expect(pending.isPending, true);
      expect(pending.parsedStatus, ProposalStatus.pending);

      const ProposalModel accepted = ProposalModel(id: 2, status: 'accepted');
      expect(accepted.isAccepted, true);
      expect(accepted.parsedStatus, ProposalStatus.accepted);

      const ProposalModel rejected = ProposalModel(id: 3, status: 'rejected');
      expect(rejected.isRejected, true);
      expect(rejected.parsedStatus, ProposalStatus.rejected);

      const ProposalModel withdrawn = ProposalModel(id: 4, status: 'withdrawn');
      expect(withdrawn.isWithdrawn, true);
      expect(withdrawn.parsedStatus, ProposalStatus.withdrawn);

      const ProposalModel cancelled = ProposalModel(id: 5, status: 'cancelled');
      expect(cancelled.isCancelled, true);
      expect(cancelled.parsedStatus, ProposalStatus.cancelled);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:ciss_mobile/core/models/training_models.dart';

void main() {
  group('GuardTrainingLeaderboard parsing', () {
    test('parses ranked scores, myRank and myEntry', () {
      final json = <String, dynamic>{
        'district': 'Ernakulam',
        'currentMonth': '2026-08',
        'scores': <dynamic>[
          <String, dynamic>{
            'rank': 1,
            'id': 'emp-1',
            'employeeName': 'Arun',
            'trainingScore': 95,
            'totalTrainingsCompleted': 4,
            'trainingAttempts': 5,
            'clientName': 'TCS',
            'district': 'Ernakulam',
          },
          <String, dynamic>{
            'rank': 2,
            'id': 'emp-2',
            'employeeName': 'Binu',
            'trainingScore': 88,
            'totalTrainingsCompleted': 3,
            'trainingAttempts': 3,
          },
        ],
        'myRank': 2,
        'myEntry': <String, dynamic>{
          'rank': 2,
          'id': 'emp-2',
          'employeeName': 'Binu',
          'trainingScore': 88,
          'totalTrainingsCompleted': 3,
          'trainingAttempts': 3,
        },
      };

      final leaderboard = GuardTrainingLeaderboard.fromJson(json);

      expect(leaderboard.district, 'Ernakulam');
      expect(leaderboard.currentMonth, '2026-08');
      expect(leaderboard.entries.length, 2);
      expect(leaderboard.entries.first.rank, 1);
      expect(leaderboard.entries.first.employeeName, 'Arun');
      expect(leaderboard.entries.first.trainingScore, 95);
      expect(leaderboard.entries.first.totalTrainingsCompleted, 4);
      expect(leaderboard.entries.first.trainingAttempts, 5);
      expect(leaderboard.myRank, 2);
      expect(leaderboard.myEntry?.id, 'emp-2');
      expect(leaderboard.myEntry?.employeeName, 'Binu');
    });

    test('parses empty and missing fields gracefully', () {
      final leaderboard = GuardTrainingLeaderboard.fromJson(<String, dynamic>{
        'district': '',
        'currentMonth': '',
      });

      expect(leaderboard.entries, isEmpty);
      expect(leaderboard.myRank, isNull);
      expect(leaderboard.myEntry, isNull);
    });

    test('handles an explicit empty scores list', () {
      final leaderboard = GuardTrainingLeaderboard.fromJson(<String, dynamic>{
        'scores': <dynamic>[],
        'myRank': null,
        'myEntry': null,
      });

      expect(leaderboard.entries, isEmpty);
      expect(leaderboard.myRank, isNull);
    });
  });
}

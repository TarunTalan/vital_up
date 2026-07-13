import 'package:vital_up/core/network/api_result.dart';
import 'package:vital_up/core/network/dio_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:vital_up/features/diet_plan/data/models/meal_plan_model.dart';
import 'package:vital_up/features/diet_plan/data/models/nutrition_target_model.dart';
import 'package:vital_up/features/diet_plan/domain/entities/nutrition_target.dart';
import 'package:vital_up/core/config/supabase_config.dart';
import 'package:dio/dio.dart';

abstract class DietPlanRemoteDataSource {
  Future<ApiResult<MealPlanModel>> generateDietPlan({
    required NutritionTarget target,
    required Map<String, dynamic> preferences,
  });
}

class DietPlanRemoteDataSourceImpl implements DietPlanRemoteDataSource {
  final DioClient _dioClient; // Kept for DI compatibility

  DietPlanRemoteDataSourceImpl(this._dioClient);

  @override
  Future<ApiResult<MealPlanModel>> generateDietPlan({
    required NutritionTarget target,
    required Map<String, dynamic> preferences,
  }) async {
    try {
      final targetModel = NutritionTargetModel.fromEntity(target);
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) {
        throw Exception('No active session — cannot call generate-diet-plan');
      }
      
      print('\n\n--- DEBUG INFO START ---');
      final anonKey = SupabaseConfig.publishableKey;
      final baseUrl = SupabaseConfig.url;
      print('CURL COMMAND TO TEST:');
      print('''
curl -i -X POST '$baseUrl/functions/v1/generate-diet-plan' \\
  -H "Authorization: Bearer $token" \\
  -H "Content-Type: application/json" \\
  -H "apikey: $anonKey" \\
  -d '{"target":{"calories":2000,"protein":150,"carbs":200,"fat":60},"preferences":{"dietaryType":"Veg","mealsPerDay":4}}'
      ''');
      
      try {
         final dioResponse = await _dioClient.dio.post(
            '$baseUrl/functions/v1/generate-diet-plan',
            data: {
              'target': targetModel.toJson(),
              'preferences': preferences,
            },
            options: Options(
              headers: {
                 'Authorization': 'Bearer $token',
                 'apikey': anonKey,
              },
              validateStatus: (status) => true,
            ),
         );
         print('RAW STATUS: ${dioResponse.statusCode}');
         print('RAW BODY: ${dioResponse.data}');
      } catch (e) {
         print('DIO ERROR: $e');
      }
      print('--- DEBUG INFO END ---\n\n');

      print('\n\n--- JWT PAYLOAD DEBUG ---');
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payloadStr = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
          final payload = jsonDecode(payloadStr);
          print('JWT Payload iss: ${payload['iss']}');
          print('JWT Payload exp: ${payload['exp']}');
          final expDate = DateTime.fromMillisecondsSinceEpoch((payload['exp'] as int) * 1000);
          print('JWT exp date: $expDate');
        }
      } catch (e) {
        print('Error decoding JWT: $e');
      }
      print('--- JWT PAYLOAD DEBUG END ---\n\n');
      
      final response = await Supabase.instance.client.functions.invoke(
        'generate-diet-plan',
        headers: {
          'Authorization': 'Bearer $token',
        },
        body: {
          'target': targetModel.toJson(),
          'preferences': preferences,
        },
      );

      if (response.status == 200) {
        final dateKey = DateTime.now().toIso8601String().split('T')[0];
        final model = MealPlanModel.fromJson(response.data as Map<String, dynamic>, dateKey);
        return ApiSuccess(model);
      } else {
        final errorMsg = response.data?['error']?.toString() ?? 'Server error';
        final details = response.data?['details']?.toString();
        return ApiError(
          message: details != null ? '$errorMsg\nDetails: $details' : errorMsg, 
          code: response.status ?? 500
        );
      }
    } on FunctionException catch (e) {
      final rawError = e.details != null ? e.details.toString() : (e.reasonPhrase ?? 'No reason phrase');
      // Use 555 so it doesn't get mapped to generic 401 text
      return ApiError(message: 'DEBUG: $rawError', code: 555);
    } catch (e) {
      final err = ResponseHandler.fromException(e) as ApiError;
      return ApiError(message: err.message, code: err.code);
    }
  }
}

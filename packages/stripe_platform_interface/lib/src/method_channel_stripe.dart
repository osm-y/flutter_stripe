import 'dart:io';

import 'package:flutter/services.dart';
import 'package:stripe_platform_interface/src/models/create_token_data.dart';

import 'models/app_info.dart';
import 'models/apple_pay.dart';
import 'models/errors.dart';
import 'models/payment_intents.dart';
import 'models/payment_methods.dart';
import 'models/payment_sheet.dart';
import 'models/setup_intent.dart';
import 'models/three_d_secure.dart';
import 'stripe_platform_interface.dart';

const _appInfo = AppInfo(
    name: 'flutter_stripe',
    version: '0.0.0',
    url: 'https://github.com/fluttercommunity/flutter_stripe/');

/// An implementation of [StripePlatform] that uses method channels.
class MethodChannelStripe extends StripePlatform {
  MethodChannelStripe({
    required MethodChannel methodChannel,
    required bool platformIsIos,
  })  : _methodChannel = methodChannel,
        _platformIsIos = platformIsIos;

  final MethodChannel _methodChannel;
  final bool _platformIsIos;

  @override
  Future<void> initialise({
    required String publishableKey,
    String? stripeAccountId,
    ThreeDSecureConfigurationParams? threeDSecureParams,
    String? merchantIdentifier,
    String? urlScheme,
  }) async {
    await _methodChannel.invokeMethod('initialise', {
      'publishableKey': publishableKey,
      'stripeAccountId': stripeAccountId,
      'merchantIdentifier': merchantIdentifier,
      'appInfo': _appInfo.toJson(),
      'threeDSecureParams': threeDSecureParams,
      'urlScheme': urlScheme,
    });
  }

  @override
  Future<PaymentMethod> createPaymentMethod(
    PaymentMethodParams data, [
    Map<String, String> options = const {},
  ]) async {
    final result = await _methodChannel
        .invokeMapMethod<String, dynamic>('createPaymentMethod', {
      'data': data.toJson(),
      'options': options,
    });

    final tmp = result?['paymentMethod'] as Map<String, dynamic>;

    return PaymentMethod.fromJson(
      tmp.unfoldToNonNull(),
    );
  }

  @override
  Future<void> confirmApplePayPayment(String clientSecret) async {
    await _methodChannel.invokeMethod('confirmApplePayPayment', {
      'clientSecret': clientSecret,
    });
  }

  @override
  Future<PaymentIntent> confirmPaymentMethod(
    String paymentIntentClientSecret,
    PaymentMethodParams params, [
    Map<String, String> options = const {},
  ]) async {
    try {
      final result = await _methodChannel
          .invokeMapMethod<String, dynamic>('confirmPaymentMethod', {
        'paymentIntentClientSecret': paymentIntentClientSecret,
        'params': params.toJson(),
        'options': options,
      });

      final tmp = result?['paymentIntent'] as Map<String, dynamic>;

      return PaymentIntent.fromJson(tmp.unfoldToNonNull());
    } on Exception catch (_) {
      throw const StripeError<PaymentIntentError>(
        code: PaymentIntentError.unknown,
        message: 'Confirming payment intent failed',
      );
    }
  }

  @override
  Future<SetupIntent> confirmSetupIntent(
    String setupIntentClientSecret,
    PaymentMethodParams data, [
    Map<String, String> options = const {},
  ]) async {
    final result = await _methodChannel
        .invokeMapMethod<String, dynamic>('confirmSetupIntent', {
      'setupIntentClientSecret': setupIntentClientSecret,
      'params': data.toJson(),
      'options': options,
    });
    final tmp = result.unfoldToNonNull();

    return SetupIntent.fromJson(tmp['setupIntent']);
  }

  @override
  Future<String> createTokenForCVCUpdate(String cvc) async {
    final result = await _methodChannel.invokeMethod<String>(
      'createTokenForCVCUpdate',
      {'cvc': cvc},
    );

    return result.unfoldToNonNull();
  }

  @override
  Future<PaymentIntent> handleCardAction(
      String paymentIntentClientSecret) async {
    try {
      final result = await _methodChannel
          .invokeMapMethod<String, dynamic>('handleCardAction', {
        'paymentIntentClientSecret': paymentIntentClientSecret,
      });

      final tmp = result?['paymentIntent'] as Map<String, dynamic>;

      return PaymentIntent.fromJson(tmp.unfoldToNonNull());
    } on Exception catch (_) {
      throw const StripeError<PaymentIntentError>(
        code: PaymentIntentError.unknown,
        message: 'Handle  payment intent for card failed',
      );
    }
  }

  @override
  Future<bool> isApplePaySupported() async {
    if (!_platformIsIos) {
      return false;
    }
    final isSupported =
        await _methodChannel.invokeMethod('isApplePaySupported');
    return isSupported ?? false;
  }

  @override
  Future<void> presentApplePay(ApplePayPresentParams params) async {
    if (!_platformIsIos) {
      throw UnsupportedError('Apple Pay is only available for iOS devices');
    }
    await _methodChannel.invokeMethod('presentApplePay', params.toJson());
  }

  @override
  Future<PaymentIntent> retrievePaymentIntent(String clientSecret) async {
    try {
      final result = await _methodChannel
          .invokeMapMethod<String, dynamic>('retrievePaymentIntent', {
        'clientSecret': clientSecret,
      });

      final tmp = result?['paymentIntent'] as Map<String, dynamic>;

      return PaymentIntent.fromJson(tmp.unfoldToNonNull());
    } on Exception catch (_) {
      throw const StripeError<PaymentIntentError>(
        code: PaymentIntentError.unknown,
        message: 'Retrieving payment intent failed',
      );
    }
  }

  @override
  Future<void> initPaymentSheet(SetupPaymentSheetParameters params) async {
    await _methodChannel.invokeMethod(
      'initPaymentSheet',
      {'params': params.toJson()},
    );
  }

  @override
  Future<PaymentSheetResult> presentPaymentSheet(
      PresentPaymentSheetParameters params) async {
    final result = await _methodChannel.invokeMethod<dynamic>(
      'presentPaymentSheet',
      {'params': params.toJson()},
    );

    // iOS returns empty list on success
    if (result is List) {
      return const PaymentSheetResult.success();
    } else {
      return _parsePaymentSheetResult(result);
    }
  }

  @override
  Future<PaymentSheetResult> confirmPaymentSheetPayment() async {
    final result = await _methodChannel
        .invokeMethod<dynamic>('confirmPaymentSheetPayment');

    return _parsePaymentSheetResult(result);
  }

  @override
  Future<TokenData> createToken(CreateTokenParams params) async {
    try {
      final result = await _methodChannel.invokeMapMethod<String, dynamic>(
          'createToken', {'params': params.toJson()});

      return TokenData.fromJson(result.unfoldToNonNull());
    } on Exception catch (e) {
      throw StripeError<CreateTokenError>(
        code: CreateTokenError.unknown,
        message: 'Create token failed with exception: $e',
      );
    }
  }

  @override
  Future<CardData> createCard(CreateTokenParams params) async {
    try {
      final result = await _methodChannel.invokeMapMethod<String, dynamic>(
          'createCard', {'params': params.toJson()});

      return CardData.fromJson(result.unfoldToNonNull());
    } on Exception catch (e) {
      throw StripeError<CreateCardError>(
        code: CreateCardError.unknown,
        message: 'Create card failed with exception: $e',
      );
    }
  }

  PaymentSheetResult _parsePaymentSheetResult(Map<String, dynamic>? result) {
    if (result != null) {
      if (result.isEmpty) {
        return const PaymentSheetResult.success();
      } else {
        if (result['error'] != null) {
          //workaround for tojson in sumtypes
          result['runtimeType'] = 'failed';
          return PaymentSheetResult.fromJson(result);
        } else {
          throw StripeError<PaymentSheetError>(
            message: 'Unknown result $result',
            code: PaymentSheetError.unknown,
          );
        }
      }
    } else {
      throw const StripeError<PaymentSheetError>(
        message: 'Result should not be null',
        code: PaymentSheetError.unknown,
      );
    }
  }
}

class MethodChannelStripeFactory {
  const MethodChannelStripeFactory();

  StripePlatform create() => MethodChannelStripe(
      methodChannel: const MethodChannel(
        'flutter.stripe/payments',
        JSONMethodCodec(),
      ),
      platformIsIos: Platform.isIOS);
}

extension UnfoldToNonNull<T> on T? {
  T unfoldToNonNull() {
    if (this == null) {
      throw AssertionError('Result should not be null');
    } else {
      return this!;
    }
  }
}

package ir.mservices.myketiap

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.gson.Gson
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import ir.myket.billingclient.IabHelper
import ir.myket.billingclient.util.IabResult
import ir.myket.billingclient.util.Inventory
import ir.myket.billingclient.util.Purchase

/** MyketPlugin - Crash-Proof and Resilient Implementation */
class MyketPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private val gson: Gson = Gson()
    private var mHelper: IabHelper? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.flutterEngine.dartExecutor, "myket")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    private fun runOnMainThread(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            block()
        } else {
            mainHandler.post(block)
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "init" -> {
                try {
                    val publicKey = call.argument<String>("rsa")
                    val enableDebugLogging = call.argument<Boolean>("enableDebugLogging")
                    mHelper = IabHelper(context, publicKey)
                    mHelper?.enableDebugLogging(enableDebugLogging == true)
                    mHelper?.startSetup { iabResult ->
                        runOnMainThread {
                            try {
                                result.success(gson.toJson(iabResult, IabResult::class.java))
                            } catch (t: Throwable) {
                                // Channel callback fallback
                            }
                        }
                    }
                } catch (t: Throwable) {
                    val errorResult = IabResult(IabHelper.BILLING_RESPONSE_RESULT_BILLING_UNAVAILABLE, t.message ?: "Init failed")
                    runOnMainThread {
                        result.success(gson.toJson(errorResult, IabResult::class.java))
                    }
                }
            }
            "launchPurchaseFlow" -> {
                val currentActivity = activity
                if (currentActivity == null) {
                    val errorResult = IabResult(IabHelper.BILLING_RESPONSE_RESULT_ERROR, "Activity is null")
                    runOnMainThread {
                        result.success(mapOf(
                            "result" to gson.toJson(errorResult, IabResult::class.java),
                            "purchase" to null
                        ))
                    }
                    return
                }

                val helper = mHelper
                if (helper == null) {
                    val errorResult = IabResult(IabHelper.BILLING_RESPONSE_RESULT_BILLING_UNAVAILABLE, "IAB helper is null")
                    runOnMainThread {
                        result.success(mapOf(
                            "result" to gson.toJson(errorResult, IabResult::class.java),
                            "purchase" to null
                        ))
                    }
                    return
                }

                val sku = call.argument<String>("sku") ?: ""
                val payload = call.argument<String>("payload")
                try {
                    val onIabPurchaseFinishedListener = IabHelper.OnIabPurchaseFinishedListener { purchaseResult: IabResult, purchase: Purchase? ->
                        runOnMainThread {
                            try {
                                result.success(mapOf(
                                    "result" to gson.toJson(purchaseResult, IabResult::class.java),
                                    "purchase" to if (purchase != null) gson.toJson(purchase, Purchase::class.java) else null
                                ))
                            } catch (t: Throwable) {
                                // Callback delivery fallback
                            }
                        }
                    }
                    helper.launchPurchaseFlow(currentActivity, sku, onIabPurchaseFinishedListener, payload)
                } catch (t: Throwable) {
                    val errorResult = IabResult(IabHelper.BILLING_RESPONSE_RESULT_ERROR, t.message ?: "Launch purchase failed")
                    runOnMainThread {
                        result.success(mapOf(
                            "result" to gson.toJson(errorResult, IabResult::class.java),
                            "purchase" to null
                        ))
                    }
                }
            }
            "consume" -> {
                val helper = mHelper
                if (helper == null) {
                    val errorResult = IabResult(IabHelper.BILLING_RESPONSE_RESULT_BILLING_UNAVAILABLE, "IAB helper is null")
                    runOnMainThread {
                        result.success(mapOf(
                            "result" to gson.toJson(errorResult, IabResult::class.java),
                            "purchase" to null
                        ))
                    }
                    return
                }

                try {
                    val rawPurchase = call.argument<String>("purchase")
                    val purchase = gson.fromJson(rawPurchase, Purchase::class.java)
                    helper.consumeAsync(purchase) { p: Purchase?, consumeResult: IabResult ->
                        runOnMainThread {
                            try {
                                result.success(mapOf(
                                    "result" to gson.toJson(consumeResult, IabResult::class.java),
                                    "purchase" to if (p != null) gson.toJson(p, Purchase::class.java) else null
                                ))
                            } catch (t: Throwable) {
                                // Callback delivery fallback
                            }
                        }
                    }
                } catch (t: Throwable) {
                    val errorResult = IabResult(IabHelper.BILLING_RESPONSE_RESULT_ERROR, t.message ?: "Consume failed")
                    runOnMainThread {
                        result.success(mapOf(
                            "result" to gson.toJson(errorResult, IabResult::class.java),
                            "purchase" to null
                        ))
                    }
                }
            }
            "getPurchase" -> {
                val helper = mHelper
                if (helper == null) {
                    val errorResult = IabResult(IabHelper.BILLING_RESPONSE_RESULT_BILLING_UNAVAILABLE, "IAB helper is null")
                    runOnMainThread {
                        result.success(mapOf(
                            "result" to gson.toJson(errorResult, IabResult::class.java),
                            "purchase" to null
                        ))
                    }
                    return
                }

                try {
                    val sku = call.argument<String>("sku") ?: ""
                    val querySkuDetails = call.argument<Boolean>("querySkuDetails")
                    helper.queryInventoryAsync(querySkuDetails == true, arrayListOf(sku)) { iabResult: IabResult, inventory: Inventory? ->
                        runOnMainThread {
                            try {
                                val purchase = inventory?.getPurchase(sku)
                                result.success(mapOf(
                                    "result" to gson.toJson(iabResult, IabResult::class.java),
                                    "purchase" to if (purchase != null) gson.toJson(purchase, Purchase::class.java) else null
                                ))
                            } catch (t: Throwable) {
                                // Callback delivery fallback
                            }
                        }
                    }
                } catch (t: Throwable) {
                    val errorResult = IabResult(IabHelper.BILLING_RESPONSE_RESULT_ERROR, t.message ?: "Get purchase failed")
                    runOnMainThread {
                        result.success(mapOf(
                            "result" to gson.toJson(errorResult, IabResult::class.java),
                            "purchase" to null
                        ))
                    }
                }
            }
            "queryInventory" -> {
                val helper = mHelper
                if (helper == null) {
                    val errorResult = IabResult(IabHelper.BILLING_RESPONSE_RESULT_BILLING_UNAVAILABLE, "IAB helper is null")
                    runOnMainThread {
                        result.success(mapOf(
                            "result" to gson.toJson(errorResult, IabResult::class.java),
                            "inventory" to null
                        ))
                    }
                    return
                }

                try {
                    val querySkuDetails = call.argument<Boolean>("querySkuDetails")
                    val skus = call.argument<List<String>>("skus") ?: emptyList()
                    helper.queryInventoryAsync(querySkuDetails == true, skus) { iabResult: IabResult, inventory: Inventory? ->
                        runOnMainThread {
                            try {
                                result.success(mapOf(
                                    "result" to gson.toJson(iabResult, IabResult::class.java),
                                    "inventory" to if (inventory != null) gson.toJson(inventory, Inventory::class.java) else null
                                ))
                            } catch (t: Throwable) {
                                // Callback delivery fallback
                            }
                        }
                    }
                } catch (t: Throwable) {
                    val errorResult = IabResult(IabHelper.BILLING_RESPONSE_RESULT_ERROR, t.message ?: "Query inventory failed")
                    runOnMainThread {
                        result.success(mapOf(
                            "result" to gson.toJson(errorResult, IabResult::class.java),
                            "inventory" to null
                        ))
                    }
                }
            }
            "dispose" -> {
                try {
                    mHelper?.dispose()
                    mHelper = null
                    runOnMainThread { result.success(true) }
                } catch (t: Throwable) {
                    runOnMainThread { result.success(false) }
                }
            }
            "subscriptionsSupported" -> {
                try {
                    val supported = mHelper?.subscriptionsSupported() == true
                    runOnMainThread { result.success(supported) }
                } catch (t: Throwable) {
                    runOnMainThread { result.success(false) }
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        try {
            mHelper?.dispose()
        } catch (_: Throwable) {}
        mHelper = null
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }
}

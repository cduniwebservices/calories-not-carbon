package com.caloriesnotcarbon.activemobility

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var barometerManager: BarometerManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.caloriesnotcarbon/barometer")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startBarometer" -> {
                        val started = barometerManager?.start() ?: false
                        result.success(started)
                    }
                    "stopBarometer" -> {
                        barometerManager?.stop()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        barometerManager = BarometerManager(this)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.caloriesnotcarbon/barometer_updates")
            .setStreamHandler(barometerManager)
    }
}

class BarometerManager(private val context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private var sensorManager: SensorManager? = null
    private var pressureSensor: Sensor? = null
    private var eventSink: EventChannel.EventSink? = null
    private var isStarted = false

    fun start(): Boolean {
        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        pressureSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_PRESSURE)
        if (pressureSensor == null) {
            android.util.Log.w("BarometerManager", "Barometer sensor not available on this device")
            return false
        }
        if (isStarted) return true
        sensorManager?.registerListener(this, pressureSensor, SensorManager.SENSOR_DELAY_UI)
        isStarted = true
        android.util.Log.i("BarometerManager", "Started")
        return true
    }

    fun stop() {
        sensorManager?.unregisterListener(this)
        isStarted = false
        android.util.Log.i("BarometerManager", "Stopped")
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        stop()
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type == Sensor.TYPE_PRESSURE && event.values.isNotEmpty()) {
            // Android TYPE_PRESSURE reports pressure in hPa (millibars)
            val pressureHpa = event.values[0].toDouble()
            eventSink?.success(pressureHpa)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}

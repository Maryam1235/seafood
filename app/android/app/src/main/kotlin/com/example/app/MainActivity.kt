package com.example.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)

            // Orders channel — high importance so it pops up on screen
            val ordersChannel = NotificationChannel(
                "zanseafood_orders",
                "Order Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for order confirmations and updates"
                enableVibration(true)
                enableLights(true)
            }
            manager.createNotificationChannel(ordersChannel)

            // Low-stock channel — high importance so it pops up as a heads-up banner
            val stockChannel = NotificationChannel(
                "zanseafood_stock",
                "Stock Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alerts when a product stock is running low or out"
                enableVibration(true)
                enableLights(true)
            }
            manager.createNotificationChannel(stockChannel)

            // General channel
            val generalChannel = NotificationChannel(
                "zanseafood_general",
                "General Notifications",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "General app notifications"
            }
            manager.createNotificationChannel(generalChannel)
        }
    }
}

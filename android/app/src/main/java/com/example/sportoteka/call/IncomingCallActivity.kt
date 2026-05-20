package com.example.sportoteka.call

import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import androidx.activity.ComponentActivity
import com.example.sportoteka.R

class IncomingCallActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_incoming_call)

        val caller = intent.getStringExtra("caller") ?: "Звонок"
        val roomId = intent.getStringExtra("roomId") ?: ""

        findViewById<TextView>(R.id.callerName).text = caller

        findViewById<Button>(R.id.btnAccept).setOnClickListener {
            // TODO: открыть твой Flutter-экран звонка/канал в WebRTC со ссылкой на roomId
            finish()
        }

        findViewById<Button>(R.id.btnDecline).setOnClickListener {
            finish()
        }
    }
}

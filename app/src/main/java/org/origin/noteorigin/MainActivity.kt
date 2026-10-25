@file:OptIn(ExperimentalMaterial3Api::class)

package org.origin.noteorigin

import androidx.compose.material3.ExperimentalMaterial3Api

import android.content.Context
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.lightColorScheme
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            NoteOriginApp()
        }
    }
}

private val DATE_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd")

@Composable
fun NoteOriginApp() {
    val context = LocalContext.current
    val prefs = remember {
        context.getSharedPreferences("secure_config", Context.MODE_PRIVATE)
    }
    val scope = rememberCoroutineScope()

    var noteText by remember { mutableStateOf("Select a date to decrypt...") }
    var aiText by remember { mutableStateOf("AI Insight will appear here...") }
    var aiBusy by remember { mutableStateOf(false) }
    var showSettings by remember { mutableStateOf(false) }
    var showCalendar by remember { mutableStateOf(false) }
    var apiError by remember { mutableStateOf<String?>(null) }

    // Material You 动态取色（Android 12+ 取壁纸色，低版本回退默认浅色）
    val colorScheme = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        dynamicLightColorScheme(context)
    } else {
        lightColorScheme()
    }

    MaterialTheme(colorScheme = colorScheme) {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("Note Origin") },
                    actions = {
                        IconButton(onClick = { showSettings = true }) {
                            Icon(Icons.Default.Settings, contentDescription = "Settings")
                        }
                        IconButton(onClick = { showCalendar = true }) {
                            Icon(Icons.Default.DateRange, contentDescription = "Calendar")
                        }
                    }
                )
            }
        ) { padding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Text(
                    text = noteText,
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth()
                        .verticalScroll(rememberScrollState()),
                    style = MaterialTheme.typography.bodyLarge
                )
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            text = aiText,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        if (aiBusy) {
                            LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
                        }
                    }
                }
            }
        }

        if (showSettings) {
            ApiKeyDialog(
                initial = prefs.getString("key", "").orEmpty(),
                onDismiss = { showSettings = false },
                onSave = { key ->
                    prefs.edit().putString("key", key).apply()
                    showSettings = false
                }
            )
        }

        if (showCalendar) {
            val pickerState = rememberDatePickerState()
            DatePickerDialog(
                onDismissRequest = { showCalendar = false },
                confirmButton = {
                    TextButton(onClick = {
                        val millis = pickerState.selectedDateMillis
                        if (millis != null) {
                            val date = Instant.ofEpochMilli(millis)
                                .atZone(ZoneId.of("UTC"))
                                .toLocalDate()
                                .format(DATE_FORMAT)
                            // 与原 Swift 内核相同的流程：混淆产出 -> 本地还原展示
                            val obfuscated = CoreLogic.executeDataPurge(date, "zh")
                            val decrypted = CoreLogic.decrypt(obfuscated)
                            noteText = "Decrypted: $decrypted"

                            val key = prefs.getString("key", "").orEmpty()
                            if (key.isNotBlank()) {
                                aiBusy = true
                                apiError = null
                                scope.launch {
                                    try {
                                        val summary = AiClient.askQwen(key, decrypted)
                                        aiText = "Qwen: $summary"
                                    } catch (e: Exception) {
                                        aiText = "AI request failed: ${e.message}"
                                    } finally {
                                        aiBusy = false
                                    }
                                }
                            }
                        }
                        showCalendar = false
                    }) { Text("OK") }
                },
                dismissButton = {
                    TextButton(onClick = { showCalendar = false }) { Text("Cancel") }
                }
            ) {
                DatePicker(state = pickerState)
            }
        }
    }
}

@Composable
fun ApiKeyDialog(
    initial: String,
    onDismiss: () -> Unit,
    onSave: (String) -> Unit
) {
    var value by remember { mutableStateOf(initial) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Settings") },
        text = {
            OutlinedTextField(
                value = value,
                onValueChange = { value = it },
                label = { Text("SiliconFlow API Key") },
                singleLine = true
            )
        },
        confirmButton = {
            TextButton(onClick = { onSave(value) }) { Text("SAVE") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}

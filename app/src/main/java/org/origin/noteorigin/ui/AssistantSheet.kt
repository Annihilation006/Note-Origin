@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package org.origin.noteorigin.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import org.origin.noteorigin.data.DayNote
import org.origin.noteorigin.data.Store
import org.origin.noteorigin.data.Txn
import org.origin.noteorigin.service.Ai
import org.origin.noteorigin.service.AiConfig
import org.origin.noteorigin.service.Assistant
import org.origin.noteorigin.service.AssistantAction
import org.origin.noteorigin.ui.theme.AppType
import org.origin.noteorigin.util.fmtMoney

/**
 * AI助手Sheet：自然语言直接记账/写笔记/查账。
 * 动作执行前在Sheet里回显将要发生的事，执行结果就地给状态。
 */
@Composable
fun AssistantSheet(
    store: Store,
    onDone: (String, InfoSeverity) -> Unit,
    onDismiss: () -> Unit,
) {
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val cs = MaterialTheme.colorScheme
    val ctx = androidx.compose.ui.platform.LocalContext.current

    var input by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf<Pair<String, InfoSeverity>?>(null) }
    var lastReply by remember { mutableStateOf<String?>(null) }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheet) {
        Column(
            Modifier
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(bottom = 32.dp)
        ) {
            Text("AI 助手", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = cs.onSurface)
            Text(
                "试试：\"记一笔午饭 25块\"、\"写笔记 今天把报告交了\"、\"这个月花了多少\"",
                fontSize = AppType.meta, color = cs.onSurfaceVariant,
                modifier = Modifier.padding(top = 4.dp, bottom = 12.dp),
            )

            OutlinedTextField(
                value = input,
                onValueChange = { input = it },
                minLines = 2, maxLines = 4,
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("想干什么直接说…") },
            )
            Spacer(Modifier.height(10.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Button(
                    onClick = {
                        val text = input.trim()
                        if (text.isEmpty() || busy) return@Button
                        val cfg = AiConfig.load(ctx)
                        if (!cfg.ready) {
                            status = "先在设置里填 API Key" to InfoSeverity.error
                            return@Button
                        }
                        busy = true; status = null; lastReply = null
                        scope.launch {
                            try {
                                val raw = Ai.chat(
                                    cfg,
                                    Assistant.userPayload(text, fmtMoney(store.monthExpense), store.monthTxns.size),
                                    system = Assistant.systemPrompt(
                                        java.time.LocalDate.now().toString(),
                                        store.cats.map { it.name },
                                        store.accs.map { it.name },
                                    ),
                                )
                                when (val act = Assistant.interpret(raw, store.cats.map { it.name }, java.time.LocalDate.now())) {
                                    is AssistantAction.AddTxn -> {
                                        val cat = store.cats.firstOrNull { it.name == act.categoryName }
                                        val acc = act.accountName?.let { n -> store.accs.firstOrNull { it.name.contains(n) || n.contains(it.name) } }
                                        store.saveTxn(
                                            Txn(
                                                type = act.type, amountCents = act.amountCents, date = act.date,
                                                categoryId = cat?.id ?: 0L,
                                                accountId = acc?.id ?: store.accs.firstOrNull()?.id ?: 0L,
                                                note = act.note.ifEmpty { "AI记" },
                                                createdAt = System.currentTimeMillis(),
                                            )
                                        )
                                        lastReply = "${act.date} ${if (act.type == 0) "支出" else "收入"} ${fmtMoney(act.amountCents)}（${act.categoryName}${act.note.take(12)}）已入账"
                                        status = "已记账 ✓" to InfoSeverity.success
                                        onDone("AI已记账 ${fmtMoney(act.amountCents)}", InfoSeverity.success)
                                    }
                                    is AssistantAction.AddNote -> {
                                        store.saveNote(
                                            DayNote(date = act.date, content = act.content, createdAt = System.currentTimeMillis())
                                        )
                                        lastReply = "「${act.content.take(40)}」已写入 ${act.date} 的笔记"
                                        status = "已写笔记 ✓" to InfoSeverity.success
                                        onDone("AI已写笔记", InfoSeverity.success)
                                    }
                                    is AssistantAction.Query, is AssistantAction.Unknown -> {
                                        val replyText = when (act) {
                                            is AssistantAction.Query -> act.question
                                            is AssistantAction.Unknown -> act.reply
                                            else -> ""
                                        }
                                        lastReply = replyText
                                        status = null
                                    }
                                }
                                input = ""
                            } catch (e: Exception) {
                                status = "请求失败 · ${e.message ?: e::class.java.simpleName}" to InfoSeverity.error
                            } finally {
                                busy = false
                            }
                        }
                    },
                    enabled = !busy && input.isNotBlank(),
                    modifier = Modifier.weight(1f).height(44.dp),
                ) { Text(if (busy) "正在处理…" else "执行") }
            }

            status?.let { (text, sev) ->
                Text(
                    text,
                    fontSize = 12.sp,
                    color = when (sev) {
                        InfoSeverity.success -> cs.primary
                        InfoSeverity.error -> cs.error
                        else -> cs.onSurfaceVariant
                    },
                    modifier = Modifier.padding(top = 8.dp),
                )
            }

            lastReply?.let { reply ->
                Spacer(Modifier.height(10.dp))
                org.origin.noteorigin.ui.theme.GlassCard(Modifier.fillMaxWidth()) {
                    Text(
                        reply,
                        fontSize = AppType.body, color = cs.onSurface,
                        modifier = Modifier.padding(14.dp),
                    )
                }
            }
        }
    }
}

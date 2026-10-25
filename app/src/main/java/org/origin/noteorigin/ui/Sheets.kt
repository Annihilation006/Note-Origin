@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class, androidx.compose.foundation.layout.ExperimentalLayoutApi::class)

package org.origin.noteorigin.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import org.origin.noteorigin.data.DayNote
import org.origin.noteorigin.data.Store
import org.origin.noteorigin.data.Txn
import org.origin.noteorigin.service.Ai
import org.origin.noteorigin.service.AiConfig
import org.origin.noteorigin.service.ApiFormat
import org.origin.noteorigin.ui.theme.AppType
import org.origin.noteorigin.util.parseMoneyToCents
import org.origin.noteorigin.util.todayStr
import java.time.Instant
import java.time.ZoneId

/**
 * 带停靠位的Sheet族：记一笔 / 笔记编辑 / 设置。就地完成操作，不跳页。
 */

@Composable
fun AddTxnSheet(
    store: Store,
    editing: Txn?,
    onDone: (String, InfoSeverity) -> Unit,
    onDismiss: () -> Unit,
) {
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val cs = MaterialTheme.colorScheme

    var type by remember { mutableStateOf(editing?.type ?: 0) }
    var amount by remember { mutableStateOf(if (editing != null) String.format("%.2f", editing.amountCents / 100.0) else "") }
    var catId by remember { mutableStateOf(editing?.categoryId ?: (store.cats.firstOrNull { it.type == (editing?.type ?: 0) }?.id ?: 0L)) }
    var accId by remember { mutableStateOf(editing?.accountId ?: (store.accs.firstOrNull()?.id ?: 0L)) }
    var date by remember { mutableStateOf(editing?.date ?: todayStr()) }
    var note by remember { mutableStateOf(editing?.note ?: "") }
    var showDate by remember { mutableStateOf(false) }
    var saving by remember { mutableStateOf(false) }

    val cats = store.cats.filter { it.type == type }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheet) {
        Column(Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 32.dp)) {
            Text(if (editing == null) "记一笔" else "编辑", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = cs.onSurface)
            Spacer(Modifier.height(14.dp))

            SegmentedControl(listOf("支出", "收入"), if (type == 0) 0 else 1) { i ->
                type = i
                catId = store.cats.firstOrNull { it.type == i }?.id ?: 0L
            }
            Spacer(Modifier.height(14.dp))

            OutlinedTextField(
                value = amount,
                onValueChange = { amount = it.filter { c -> c.isDigit() || c == '.' }.take(12) },
                textStyle = androidx.compose.ui.text.TextStyle(fontSize = 30.sp, fontWeight = FontWeight.Bold),
                label = { Text("金额") },
                prefix = { Text("¥", fontSize = 22.sp) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(12.dp))

            // 分类：芯片网格
            Text("分类", fontSize = AppType.meta, color = cs.onSurfaceVariant)
            androidx.compose.foundation.layout.FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.padding(top = 8.dp),
            ) {
                cats.forEach { c ->
                    val sel = c.id == catId
                    androidx.compose.material3.FilterChip(
                        selected = sel,
                        onClick = { catId = c.id ?: 0L },
                        label = { Text("${c.icon} ${c.name}", fontSize = 13.sp) },
                    )
                }
            }
            Spacer(Modifier.height(12.dp))

            // 账户下拉
            var accMenu by remember { mutableStateOf(false) }
            val accName = store.accById[accId]?.name ?: "选择账户"
            ExposedDropdownMenuBox(expanded = accMenu, onExpandedChange = { accMenu = it }) {
                OutlinedTextField(
                    value = accName,
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("账户") },
                    modifier = Modifier.fillMaxWidth().menuAnchor(),
                    trailingIcon = { Text("▾", fontSize = 14.sp) },
                )
                ExposedDropdownMenu(expanded = accMenu, onDismissRequest = { accMenu = false }) {
                    store.accs.forEach { a ->
                        DropdownMenuItem(text = { Text(a.name) }, onClick = { accId = a.id ?: 0L; accMenu = false })
                    }
                }
            }
            Spacer(Modifier.height(12.dp))

            Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                OutlinedTextField(
                    value = date,
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("日期") },
                    modifier = Modifier.weight(1f),
                    trailingIcon = {
                        TextButton(onClick = { showDate = true }) { Text("改") }
                    },
                )
            }
            Spacer(Modifier.height(12.dp))

            OutlinedTextField(
                value = note,
                onValueChange = { note = it },
                label = { Text("备注（可空）") },
                minLines = 1, maxLines = 3,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(18.dp))

            androidx.compose.material3.Button(
                onClick = {
                    if (saving) return@Button
                    val cents = parseMoneyToCents(amount)
                    if (cents == null || cents <= 0) {
                        onDone("金额不对，检查一下", InfoSeverity.error); return@Button
                    }
                    if (catId == 0L) {
                        onDone("选个分类", InfoSeverity.error); return@Button
                    }
                    if (accId == 0L) {
                        onDone("没有可用账户", InfoSeverity.error); return@Button
                    }
                    saving = true
                    scope.launch {
                        store.saveTxn(
                            Txn(
                                id = editing?.id, type = type, amountCents = cents,
                                categoryId = catId, accountId = accId, date = date, note = note.trim(),
                                createdAt = editing?.createdAt ?: System.currentTimeMillis(),
                            )
                        )
                        onDone(if (editing == null) "已记下" else "已更新", InfoSeverity.success)
                        onDismiss()
                    }
                },
                enabled = !saving,
                modifier = Modifier.fillMaxWidth().height(50.dp),
            ) { Text(if (saving) "保存中…" else "保存", fontSize = 15.sp) }
        }
    }

    if (showDate) {
        val dp = rememberDatePickerState(initialSelectedDateMillis = Instant.parse(date + "T00:00:00Z").toEpochMilli())
        DatePickerDialog(
            onDismissRequest = { showDate = false },
            confirmButton = {
                TextButton(onClick = {
                    dp.selectedDateMillis?.let {
                        date = Instant.ofEpochMilli(it).atZone(ZoneId.of("UTC")).toLocalDate().toString()
                    }
                    showDate = false
                }) { Text("确定") }
            },
            dismissButton = { TextButton(onClick = { showDate = false }) { Text("取消") } },
        ) { DatePicker(state = dp) }
    }
}

@Composable
fun NoteEditSheet(
    store: Store,
    editing: DayNote,
    onDone: (String, InfoSeverity) -> Unit,
    onDismiss: () -> Unit,
) {
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val cs = MaterialTheme.colorScheme
    var content by remember { mutableStateOf(editing.content) }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheet) {
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 32.dp)) {
            Text("${editing.date} 的笔记", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = cs.onSurface)
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = content,
                onValueChange = { content = it },
                minLines = 4, maxLines = 8,
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("这一天发生了什么…") },
            )
            Spacer(Modifier.height(16.dp))
            Row {
                androidx.compose.material3.Button(
                    onClick = {
                        val text = content.trim()
                        if (text.isEmpty()) {
                            onDone("写点内容再保存", InfoSeverity.error); return@Button
                        }
                        scope.launch {
                            store.saveNote(
                                DayNote(
                                    id = if (editing.createdAt == 0L) null else editing.id,
                                    date = editing.date, content = text,
                                    createdAt = if (editing.createdAt == 0L) System.currentTimeMillis() else editing.createdAt,
                                )
                            )
                            onDone("已保存", InfoSeverity.success)
                            onDismiss()
                        }
                    },
                    modifier = Modifier.weight(1f).height(48.dp),
                ) { Text("保存") }
            }
        }
    }
}

@Composable
fun SettingsSheet(
    ctx: android.content.Context,
    store: Store,
    onDone: (String, InfoSeverity) -> Unit,
    onDismiss: () -> Unit,
) {
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val cs = MaterialTheme.colorScheme

    val cfg = remember { AiConfig.load(ctx) }
    var fmt by remember { mutableStateOf(cfg.format) }
    var base by remember { mutableStateOf(cfg.baseUrl) }
    var key by remember { mutableStateOf(cfg.apiKey) }
    var model by remember { mutableStateOf(cfg.model) }
    var obscure by remember { mutableStateOf(true) }
    var testing by remember { mutableStateOf(false) }
    var newAcc by remember { mutableStateOf("") }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheet) {
        Column(Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 40.dp)) {
            Text("设置", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = cs.onSurface)
            Spacer(Modifier.height(16.dp))

            Text("AI 助手", fontSize = AppType.section, fontWeight = FontWeight.Bold, color = cs.onSurface)
            Spacer(Modifier.height(8.dp))
            SegmentedControl(ApiFormat.entries.map { it.label }, ApiFormat.entries.indexOf(fmt)) { i ->
                // 只切协议，已填内容不动
                fmt = ApiFormat.entries[i]
            }
            Spacer(Modifier.height(10.dp))
            OutlinedTextField(
                value = base, onValueChange = { base = it },
                label = { Text("API Base URL") },
                placeholder = { Text(fmt.baseHint, fontSize = 12.sp) },
                singleLine = true, modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(10.dp))
            OutlinedTextField(
                value = key, onValueChange = { key = it },
                label = { Text("API Key") },
                visualTransformation = if (obscure) PasswordVisualTransformation() else VisualTransformation.None,
                trailingIcon = {
                    TextButton(onClick = { obscure = !obscure }) { Text(if (obscure) "显示" else "隐藏") }
                },
                singleLine = true, modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(10.dp))
            OutlinedTextField(
                value = model, onValueChange = { model = it },
                label = { Text("模型名") },
                placeholder = { Text(fmt.modelHint, fontSize = 12.sp) },
                singleLine = true, modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(10.dp))
            Row {
                TextButton(
                    onClick = {
                        if (testing) return@TextButton
                        val probe = AiConfig().apply {
                            baseUrl = base; apiKey = key; model = model; format = fmt
                        }
                        if (!probe.ready) {
                            onDone("先填 Base URL 和 Key", InfoSeverity.error); return@TextButton
                        }
                        testing = true
                        scope.launch {
                            try {
                                Ai.ping(probe)
                                onDone("连通正常", InfoSeverity.success)
                            } catch (e: Exception) {
                                onDone("不通: ${e.message}", InfoSeverity.error)
                            } finally {
                                testing = false
                            }
                        }
                    },
                    enabled = !testing,
                ) { Text(if (testing) "测试中…" else "测试连通") }
                Spacer(Modifier.weight(1f))
                androidx.compose.material3.Button(onClick = {
                    cfg.baseUrl = base.trim(); cfg.apiKey = key.trim(); cfg.model = model.trim(); cfg.format = fmt
                    cfg.save(ctx)
                    onDone("已保存", InfoSeverity.success)
                }) { Text("保存") }
            }

            Spacer(Modifier.height(20.dp))
            Text("账户", fontSize = AppType.section, fontWeight = FontWeight.Bold, color = cs.onSurface)
            Spacer(Modifier.height(6.dp))
            store.accs.forEach { Text(it.name, fontSize = AppType.body, color = cs.onSurface, modifier = Modifier.padding(vertical = 4.dp)) }
            Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                OutlinedTextField(
                    value = newAcc, onValueChange = { newAcc = it },
                    label = { Text("新账户名称") },
                    singleLine = true, modifier = Modifier.weight(1f),
                )
                TextButton(onClick = {
                    val n = newAcc.trim()
                    if (n.isEmpty()) return@TextButton
                    scope.launch {
                        store.addAccount(n)
                        newAcc = ""
                        onDone("已添加 $n", InfoSeverity.success)
                    }
                }) { Text("添加") }
            }

            Spacer(Modifier.height(20.dp))
            Text("数据", fontSize = AppType.section, fontWeight = FontWeight.Bold, color = cs.onSurface)
            Spacer(Modifier.height(6.dp))
            TextButton(onClick = {
                scope.launch {
                    try {
                        val lines = mutableListOf("date,type,category,account,amount_yuan,note")
                        val db = org.origin.noteorigin.data.Db.get(ctx)
                        for (t in db.allTxns()) {
                            val cat = store.catById[t.categoryId]?.name ?: ""
                            val acc = store.accById[t.accountId]?.name ?: ""
                            lines += "\"${t.date}\",${if (t.type == 0) "expense" else "income"},\"$cat\",\"$acc\",${String.format("%.2f", t.amountCents / 100.0)},\"${t.note.replace("\"", "\"\"")}\""
                        }
                        val f = org.origin.noteorigin.util.exportCsv(ctx, lines)
                        onDone("已导出：${f.absolutePath}", InfoSeverity.success)
                    } catch (e: Exception) {
                        onDone("导出失败: ${e.message}", InfoSeverity.error)
                    }
                }
            }) { Text("导出全部流水 (CSV)") }

            Spacer(Modifier.height(24.dp))
            Text("Note Origin v0.4.0", fontSize = AppType.meta, color = cs.onSurfaceVariant)
        }
    }
}

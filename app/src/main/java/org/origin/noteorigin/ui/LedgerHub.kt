@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class, androidx.compose.animation.ExperimentalSharedTransitionApi::class, androidx.compose.foundation.ExperimentalFoundationApi::class)

package org.origin.noteorigin.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.animation.SharedTransitionScope
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import org.origin.noteorigin.data.Store
import org.origin.noteorigin.data.Txn
import org.origin.noteorigin.service.Ai
import org.origin.noteorigin.service.AiConfig
import org.origin.noteorigin.ui.theme.AppType
import org.origin.noteorigin.ui.theme.MassBlock
import org.origin.noteorigin.ui.theme.Motion
import org.origin.noteorigin.ui.theme.chartPalette
import org.origin.noteorigin.ui.theme.reduceMotion
import org.origin.noteorigin.util.fmtMoney
import org.origin.noteorigin.util.parseMoneyToCents

/**
 * 账本枢纽：Pivot三页（明细/统计/预算），信息密集区——无流动背景，玻璃≤1层。
 */
@Composable
fun LedgerHub(
    store: Store,
    shared: SharedTransitionScope,
    av: AnimatedVisibilityScope,
    onEditTxn: (Txn?) -> Unit,
    onInfo: (String, InfoSeverity) -> Unit,
) {
    val cs = MaterialTheme.colorScheme
    var page by remember { mutableIntStateOf(0) }
    val rm = reduceMotion()

    Column(Modifier.fillMaxSize()) {
        // 顶部：月份 + 容器变换来源块（与今日的支出条同源）
        with(shared) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(start = 20.dp, end = 8.dp, top = 40.dp)
                    .sharedElement(rememberSharedContentState("money"), av),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text("${store.month.year}年${store.month.monthValue}月", fontSize = 24.sp, fontWeight = FontWeight.Bold, color = cs.onSurface)
                    Text(
                        "支出 ${fmtMoney(store.monthExpense)} · 收入 ${fmtMoney(store.monthIncome)}",
                        fontSize = AppType.meta, color = cs.onSurfaceVariant,
                    )
                }
                Text("‹", fontSize = 24.sp, color = cs.onSurfaceVariant, modifier = Modifier.clickable { store.prevMonth() }.padding(6.dp))
                Text("›", fontSize = 24.sp, color = cs.onSurfaceVariant, modifier = Modifier.clickable { store.nextMonth() }.padding(6.dp))
            }
        }

        PivotTabs(listOf("明细", "统计", "预算"), page, { page = it })

        AnimatedContent(
            targetState = page,
            transitionSpec = {
                if (rm) fadeIn(tween(Motion.fast)) togetherWith fadeOut(tween(Motion.fast))
                else {
                    val dir = if (targetState > initialState) 1 else -1
                    (slideInHorizontally(tween(Motion.normal, easing = Motion.emphasized)) { it / 5 * dir } +
                        fadeIn(tween(Motion.normal))) togetherWith
                        (slideOutHorizontally(tween(Motion.fast)) { -it / 5 * dir } + fadeOut(tween(Motion.fast)))
                }
            },
            label = "pivot",
        ) { p ->
            when (p) {
                0 -> RecordsPage(store, onEditTxn, onInfo)
                1 -> StatsPage(store)
                else -> BudgetPage(store)
            }
        }
    }
}

// ---------- 明细 ----------

@Composable
private fun RecordsPage(store: Store, onEditTxn: (Txn?) -> Unit, onInfo: (String, InfoSeverity) -> Unit) {
    val cs = MaterialTheme.colorScheme
    val scope = rememberCoroutineScope()
    val grouped = store.groupedByDay()

    LazyColumn(Modifier.fillMaxSize(), contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = 120.dp)) {
        if (grouped.isEmpty()) {
            item { Text("这个月还没有记录", fontSize = AppType.meta, color = cs.onSurfaceVariant, modifier = Modifier.padding(24.dp)) }
        }
        grouped.forEach { (day, list) ->
            item(key = "h$day") {
                Row(
                    Modifier.fillMaxWidth().padding(start = 24.dp, end = 24.dp, top = 14.dp, bottom = 4.dp),
                ) {
                    Text(day, fontSize = AppType.meta, fontWeight = FontWeight.SemiBold, color = cs.onSurface)
                    Spacer(Modifier.weight(1f))
                    Text("支出 ${fmtMoney(list.filter { it.type == 0 && it.currency == "CNY" }.sumOf { it.amountCents })}", fontSize = AppType.meta, color = cs.onSurfaceVariant)
                }
            }
            items(list, key = { it.id ?: it.createdAt }) { t ->
                val cat = store.catById[t.categoryId]
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                        .animateItem()
                        .combinedClickable(
                            onClick = { onEditTxn(t) },
                            onLongClick = {
                                scope.launch {
                                    store.deleteTxn(t.id ?: return@launch)
                                    onInfo("已删除", InfoSeverity.success)
                                }
                            },
                        )
                        .padding(vertical = 10.dp, horizontal = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(cat?.icon ?: "❓", fontSize = 22.sp, modifier = Modifier.width(40.dp), textAlign = TextAlign.Center)
                    Column(Modifier.weight(1f)) {
                        Text(cat?.name ?: "已删除分类", fontSize = AppType.body, color = cs.onSurface)
                        if (t.note.isNotEmpty()) {
                            Text(t.note, fontSize = AppType.meta, color = cs.onSurfaceVariant, maxLines = 1, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis)
                        }
                    }
                    Text(
                        (if (t.type == 0) "-" else "+") + fmtMoney(t.amountCents, currency = t.currency),
                        fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
                        color = if (t.type == 0) cs.onSurface else cs.primary,
                    )
                }
                Box(Modifier.fillMaxWidth().padding(start = 64.dp).height(1.dp).background(cs.outlineVariant.copy(alpha = 0.3f)))
            }
        }
    }
}

// ---------- 统计 ----------

@Composable
private fun StatsPage(store: Store) {
    val cs = MaterialTheme.colorScheme
    var aiBusy by remember { mutableStateOf(false) }
    var aiReply by remember { mutableStateOf<String?>(null) }
    var aiError by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val ctx = androidx.compose.ui.platform.LocalContext.current

    val byCat = store.expenseByCategory()
    val daily = store.dailyExpense()
    val total = store.monthExpense
    val palette = chartPalette(cs, byCat.size)

    LazyColumn(Modifier.fillMaxSize(), contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = 120.dp)) {
        item {
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("支出构成", fontSize = AppType.section, fontWeight = FontWeight.Bold, color = cs.onSurface, modifier = Modifier.weight(1f))
                TextButton(
                    onClick = {
                        val cfg = AiConfig.load(ctx)
                        if (!cfg.ready) {
                            aiError = "先在设置里填 API Key"
                            return@TextButton
                        }
                        if (store.monthTxns.isEmpty()) {
                            aiError = "本月没有账单数据"
                            return@TextButton
                        }
                        aiBusy = true; aiReply = null; aiError = null
                        scope.launch {
                            try {
                                aiReply = Ai.chat(cfg, store.monthSummaryText(), system = "你是一个个人财务助手。根据用户的月度账单，用简洁的中文给出：1)消费习惯总结 2)2-3条省钱建议 3)下月预算建议金额。控制在300字内，别客套。")
                            } catch (e: Exception) {
                                aiError = "AI请求失败: ${e.message}"
                            } finally {
                                aiBusy = false
                            }
                        }
                    },
                    enabled = !aiBusy,
                ) {
                    Text("AI 月报", fontSize = AppType.meta, color = cs.primary)
                }
            }
        }
        item {
            // 饼图：Canvas绘制，色板从scheme派生
            Box(Modifier.fillMaxWidth().height(200.dp), contentAlignment = Alignment.Center) {
                if (byCat.isEmpty()) {
                    Text("本月没有支出", fontSize = AppType.meta, color = cs.onSurfaceVariant)
                } else {
                    Canvas(Modifier.matchParentSize()) {
                        var start = -90f
                        val diameter = size.minDimension * 0.8f
                        val topLeft = Offset((size.width - diameter) / 2f, (size.height - diameter) / 2f)
                        byCat.forEachIndexed { i, e ->
                            val sweep = if (total <= 0) 0f else e.second.toFloat() / total * 360f
                            drawArc(
                                color = palette[i],
                                startAngle = start,
                                sweepAngle = sweep,
                                useCenter = true,
                                topLeft = topLeft,
                                size = Size(diameter, diameter),
                            )
                            start += sweep
                        }
                        // 中心挖洞（环形，更编辑一些）
                        drawCircle(cs.surface, radius = diameter * 0.30f)
                    }
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(fmtMoney(total), fontSize = AppType.figure, fontWeight = FontWeight.Bold, color = cs.onSurface)
                        Text(
                            if (store.foreignSums.isEmpty()) "共支出（¥）" else "共支出（¥）· 另有外币未计入",
                            fontSize = 10.sp, color = cs.onSurfaceVariant,
                        )
                    }
                }
            }
        }
        item {
            Text("每日支出", fontSize = AppType.section, fontWeight = FontWeight.Bold, color = cs.onSurface, modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp))
            Canvas(Modifier.fillMaxWidth().height(110.dp).padding(horizontal = 20.dp)) {
                if (daily.isEmpty()) return@Canvas
                val maxV = daily.max().coerceAtLeast(1)
                val gap = 3.dp.toPx()
                val bw = (size.width - gap * (daily.size - 1)) / daily.size
                daily.forEachIndexed { i, v ->
                    val h = if (maxV == 0L) 0f else v.toFloat() / maxV * (size.height - 14f)
                    drawRoundRect(
                        color = cs.primary.copy(alpha = 0.85f),
                        topLeft = Offset(i * (bw + gap), size.height - h),
                        size = Size(bw, h),
                        cornerRadius = androidx.compose.ui.geometry.CornerRadius(3.dp.toPx(), 3.dp.toPx()),
                    )
                }
            }
        }
        item {
            Text("分类排行", fontSize = AppType.section, fontWeight = FontWeight.Bold, color = cs.onSurface, modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp))
        }
        items(byCat.size) { i ->
            val e = byCat[i]
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("${e.first?.icon ?: "❓"} ${e.first?.name ?: "?"}", fontSize = 13.sp, color = cs.onSurface, modifier = Modifier.width(96.dp))
                Box(Modifier.weight(1f).height(6.dp).background(cs.surfaceContainerHighest, RoundedCornerShape(3.dp))) {
                    Box(
                        Modifier
                            .fillMaxWidth(if (total <= 0) 0f else e.second.toFloat() / total)
                            .height(6.dp)
                            .background(palette[i], RoundedCornerShape(3.dp))
                    )
                }
                Text(fmtMoney(e.second), fontSize = 12.sp, color = cs.onSurfaceVariant, modifier = Modifier.padding(start = 10.dp))
            }
        }
        if (aiBusy) {
            item { Text("AI正在看你的账单…", fontSize = AppType.meta, color = cs.onSurfaceVariant, modifier = Modifier.padding(20.dp)) }
        }
    }

    // AI结果/错误弹层
    aiReply?.let { reply ->
        AlertDialog(
            onDismissRequest = { aiReply = null },
            title = { Text("AI 月报") },
            text = { Text(reply) },
            confirmButton = { TextButton(onClick = { aiReply = null }) { Text("好的") } },
        )
    }
    aiError?.let { err ->
        AlertDialog(
            onDismissRequest = { aiError = null },
            title = { Text("提示") },
            text = { Text(err) },
            confirmButton = { TextButton(onClick = { aiError = null }) { Text("知道了") } },
        )
    }
}

// ---------- 预算 ----------

@Composable
private fun BudgetPage(store: Store) {
    val cs = MaterialTheme.colorScheme
    val scope = rememberCoroutineScope()
    val totalBudget = store.budgetOf(0L)?.amountCents ?: 0L
    val spent = store.monthExpense
    val over = totalBudget > 0 && spent > totalBudget

    LazyColumn(Modifier.fillMaxSize(), contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = 120.dp)) {
        item {
            MassBlock(
                Modifier.fillMaxWidth().padding(20.dp),
                tonal = if (over) cs.errorContainer else cs.secondaryContainer,
            ) {
                Column(Modifier.padding(20.dp)) {
                    Text("本月总预算", fontSize = AppType.meta, color = if (over) cs.onErrorContainer else cs.onSecondaryContainer)
                    Text(
                        if (totalBudget > 0) fmtMoney(totalBudget) else "未设置",
                        fontSize = 30.sp, fontWeight = FontWeight.Bold,
                        color = if (over) cs.onErrorContainer else cs.onSecondaryContainer,
                    )
                    if (totalBudget > 0) {
                        Spacer(Modifier.height(8.dp))
                        Box(Modifier.fillMaxWidth().height(10.dp).background(cs.surface.copy(alpha = 0.35f), RoundedCornerShape(5.dp))) {
                            Box(
                                Modifier
                                    .fillMaxWidth((spent.toFloat() / totalBudget).coerceIn(0f, 1f))
                                    .height(10.dp)
                                    .background(if (over) cs.error else cs.primary, RoundedCornerShape(5.dp))
                            )
                        }
                        Text(
                            if (over) "已超支 ${fmtMoney(spent - totalBudget)}"
                            else "已用 ${fmtMoney(spent)} / 剩余 ${fmtMoney(totalBudget - spent)}",
                            fontSize = AppType.meta,
                            color = if (over) cs.onErrorContainer else cs.onSecondaryContainer,
                            modifier = Modifier.padding(top = 6.dp),
                        )
                    }
                    InlineMoneyEdit(
                        initial = totalBudget,
                        label = if (totalBudget > 0) "修改总预算" else "设置总预算",
                    ) { cents ->
                        scope.launch { store.saveBudget(org.origin.noteorigin.data.Budget(categoryId = 0, amountCents = cents)) }
                    }
                }
            }
        }
        item {
            Text("分类预算", fontSize = AppType.section, fontWeight = FontWeight.Bold, color = cs.onSurface, modifier = Modifier.padding(horizontal = 20.dp))
        }
        items(store.cats.filter { it.type == 0 }.size) { i ->
            val cat = store.cats.filter { it.type == 0 }[i]
            val b = store.budgetOf(cat.id ?: -1)
            val used = store.expenseByCategory().firstOrNull { it.first?.id == cat.id }?.second ?: 0
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("${cat.icon} ${cat.name}", fontSize = 13.sp, color = cs.onSurface, modifier = Modifier.width(96.dp))
                Column(Modifier.weight(1f)) {
                    if (b != null && b.amountCents > 0) {
                        Box(Modifier.fillMaxWidth().height(5.dp).background(cs.surfaceContainerHighest, RoundedCornerShape(3.dp))) {
                            Box(
                                Modifier
                                    .fillMaxWidth((used.toFloat() / b.amountCents).coerceIn(0f, 1f))
                                    .height(5.dp)
                                    .background(cs.primary, RoundedCornerShape(3.dp))
                            )
                        }
                    }
                }
                Text(
                    if (b != null && b.amountCents > 0) fmtMoney(b.amountCents) else "未设置",
                    fontSize = 12.sp, color = cs.onSurfaceVariant, modifier = Modifier.padding(start = 10.dp),
                )
                InlineMoneyEdit(
                    initial = b?.amountCents ?: 0,
                    label = "编辑",
                    compact = true,
                ) { cents ->
                    scope.launch { store.saveBudget(org.origin.noteorigin.data.Budget(categoryId = cat.id ?: 0, amountCents = cents)) }
                }
            }
        }
    }
}

/** 就地内联金额编辑：点开变成输入框，收起即保存 */
@Composable
private fun InlineMoneyEdit(
    initial: Long,
    label: String,
    compact: Boolean = false,
    onSave: (Long) -> Unit,
) {
    var editing by remember { mutableStateOf(false) }
    var text by remember { mutableStateOf(if (initial > 0) String.format("%.2f", initial / 100.0) else "") }
    val cs = MaterialTheme.colorScheme

    Row(
        Modifier.animateContentSize(tween(Motion.normal, easing = Motion.emphasized)),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (!editing) {
            Text(
                label,
                fontSize = AppType.meta, color = cs.primary,
                modifier = Modifier
                    .clickableNoIndication { editing = true }
                    .padding(start = if (compact) 6.dp else 0.dp, top = 6.dp, bottom = 6.dp),
            )
        } else {
            OutlinedTextField(
                value = text,
                onValueChange = { text = it },
                textStyle = androidx.compose.ui.text.TextStyle(fontSize = 14.sp),
                modifier = Modifier.width(130.dp),
                singleLine = true,
                prefix = { Text("¥", fontSize = 13.sp) },
            )
            TextButton(onClick = {
                val cents = parseMoneyToCents(text)
                if (cents != null && cents > 0) {
                    onSave(cents)
                    editing = false
                }
            }) { Text("保存") }
            TextButton(onClick = { editing = false }) { Text("取消") }
        }
    }
}

private fun Modifier.clickableNoIndication(onClick: () -> Unit): Modifier =
    this.combinedClickable(onClick = onClick)

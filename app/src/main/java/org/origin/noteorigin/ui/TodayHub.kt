@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class, androidx.compose.animation.ExperimentalSharedTransitionApi::class)

package org.origin.noteorigin.ui

import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.animation.SharedTransitionScope
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.origin.noteorigin.data.Store
import org.origin.noteorigin.service.Hitokoto
import org.origin.noteorigin.service.Quote
import org.origin.noteorigin.ui.theme.AmbientFlow
import org.origin.noteorigin.ui.theme.AppType
import org.origin.noteorigin.ui.theme.GlassCard
import org.origin.noteorigin.ui.theme.MassBlock
import org.origin.noteorigin.ui.theme.Motion
import org.origin.noteorigin.ui.theme.reduceMotion
import org.origin.noteorigin.util.fmtMoney
import java.time.LocalDate
import java.time.format.DateTimeFormatter

/**
 * 今日枢纽：氛围开场（唯一允许流动背景的区域）+ 一言 + 支出色块条 + 继续写 + 最近。
 */
@Composable
fun TodayHub(
    store: Store,
    shared: SharedTransitionScope,
    av: AnimatedVisibilityScope,
    onOpenNotes: () -> Unit,
    onOpenLedger: () -> Unit,
    onWriteNote: (String) -> Unit,
    onOpenSettings: () -> Unit,
) {
    var quote by remember { mutableStateOf<Quote?>(null) }
    LaunchedEffect(Unit) {
        quote = Hitokoto.fetch()
    }

    val cs = MaterialTheme.colorScheme
    val now = LocalDate.now()
    val recent = store.recentNotes
    val latest = recent.firstOrNull()

    Box(Modifier.fillMaxSize()) {
        // 氛围流动层：只垫在开场区，且reduceMotion时静止
        Box(
            Modifier
                .fillMaxWidth()
                .height(300.dp)
                .clip(RoundedCornerShape(bottomStart = 28.dp, bottomEnd = 28.dp))
        ) {
            AmbientFlow(Modifier.fillMaxSize())
        }

        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp),
        ) {
            Row(
                Modifier.fillMaxWidth().padding(top = 40.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "${now.monthValue}月${now.dayOfMonth}日 星期${weekZh(now.dayOfWeek.value)}",
                    fontSize = AppType.meta, letterSpacing = 2.sp,
                    fontWeight = FontWeight.Medium,
                    color = cs.onSurfaceVariant,
                    modifier = Modifier.weight(1f),
                )
                Text(
                    "设置",
                    fontSize = AppType.meta, color = cs.onSurfaceVariant,
                    modifier = Modifier.clickable { onOpenSettings() }.padding(8.dp),
                )
            }
            Text(
                "今日",
                fontSize = AppType.display,
                fontWeight = FontWeight.ExtraLight,
                letterSpacing = (-1.5).sp,
                color = cs.onSurface,
            )

            Spacer(Modifier.height(18.dp))

            // 一言：玻璃面（第1层玻璃）
            GlassCard(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text(quote?.text ?: "", fontSize = AppType.body, lineHeight = 24.sp, color = cs.onSurface)
                    Spacer(Modifier.height(4.dp))
                    Text(quote?.from ?: "", fontSize = AppType.meta, color = cs.onSurfaceVariant)
                }
            }

            Spacer(Modifier.height(24.dp))

            // 支出条：Metro色块（环境染色tonal+直角几何+排版数字），容器变换到账本
            with(shared) {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .sharedElement(rememberSharedContentState("money"), av)
                        .height(96.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    MassBlock(
                        Modifier
                            .weight(0.58f)
                            .clickable { onOpenLedger() },
                        tonal = cs.secondaryContainer,
                    ) {
                        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.Center) {
                            Text("本月支出", fontSize = AppType.meta, color = cs.onSecondaryContainer)
                            Text(
                                fmtMoney(store.monthExpense),
                                fontSize = AppType.figure, fontWeight = FontWeight.SemiBold,
                                color = cs.onSecondaryContainer,
                            )
                            Text(
                                "收入 ${fmtMoney(store.monthIncome)}",
                                fontSize = AppType.meta,
                                color = cs.onSecondaryContainer.copy(alpha = 0.75f),
                            )
                        }
                    }
                    MassBlock(
                        Modifier
                            .weight(0.42f)
                            .clickable { onOpenLedger() },
                        tonal = cs.surfaceContainerHighest,
                    ) {
                        Column(
                            Modifier.padding(14.dp).fillMaxSize(),
                            verticalArrangement = Arrangement.Center,
                        ) {
                            Text("今天记了 ${store.todayTxnCount} 笔", fontSize = AppType.meta, color = cs.onSurfaceVariant)
                            Spacer(Modifier.height(6.dp))
                            Text("支出 ${fmtMoney(store.todayExpense)}", fontSize = AppType.meta, color = cs.onSurfaceVariant)
                        }
                    }
                }
            }

            Spacer(Modifier.height(28.dp))

            // 继续写：特稿块，容器变换到笔记
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("笔记", fontSize = AppType.section, fontWeight = FontWeight.Bold, color = cs.onSurface, modifier = Modifier.weight(1f))
                Text(
                    "写笔记",
                    fontSize = AppType.meta, color = cs.primary,
                    modifier = Modifier.clickable { onWriteNote(LocalDate.now().toString()) }.padding(8.dp),
                )
            }
            with(shared) {
                Box(
                    Modifier
                        .fillMaxWidth()
                        .sharedElement(rememberSharedContentState("feature"), av)
                        .clickable { onOpenNotes() },
                ) {
                    if (latest == null) {
                        MassBlock(Modifier.fillMaxWidth(), tonal = cs.surfaceContainer) {
                            Text(
                                "还没有写过。第一条从这里开始。",
                                fontSize = AppType.body, color = cs.onSurfaceVariant,
                                modifier = Modifier.padding(16.dp),
                            )
                        }
                    } else {
                        MassBlock(Modifier.fillMaxWidth(), tonal = cs.surfaceContainer) {
                            Column(Modifier.padding(16.dp)) {
                                Text(
                                    latest.content,
                                    fontSize = AppType.feature, fontWeight = FontWeight.SemiBold,
                                    lineHeight = 30.sp, color = cs.onSurface,
                                    maxLines = 3,
                                    overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                                )
                                Spacer(Modifier.height(6.dp))
                                Text("${latest.date} 的笔记", fontSize = AppType.meta, color = cs.onSurfaceVariant)
                            }
                        }
                    }
                }
            }

            Spacer(Modifier.height(24.dp))

            Text("最近", fontSize = AppType.section, fontWeight = FontWeight.Bold, color = cs.onSurface)
            Spacer(Modifier.height(4.dp))
            if (recent.isEmpty()) {
                Text("写点什么，都会留在这。", fontSize = AppType.meta, color = cs.onSurfaceVariant)
            } else {
                recent.forEachIndexed { i, n ->
                    Column {
                        Row(
                            Modifier.fillMaxWidth().clickable { onOpenNotes() }.padding(vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(n.date.takeLast(5), fontSize = AppType.meta, color = cs.onSurfaceVariant, modifier = Modifier.widthTag())
                            Text(
                                n.content,
                                fontSize = AppType.body, color = cs.onSurface,
                                maxLines = 1, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                            )
                        }
                        if (i != recent.lastIndex) {
                            Box(Modifier.fillMaxWidth().height(1.dp).background(cs.outlineVariant.copy(alpha = 0.35f)))
                        }
                    }
                }
            }
            Spacer(Modifier.height(32.dp))
        }
    }
}

private fun Modifier.widthTag(): Modifier = this.then(Modifier.padding(end = 12.dp))

private fun weekZh(d: Int): String = listOf("一", "二", "三", "四", "五", "六", "日")[d - 1]

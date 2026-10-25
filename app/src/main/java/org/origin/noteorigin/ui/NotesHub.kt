@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class, androidx.compose.animation.ExperimentalSharedTransitionApi::class)

package org.origin.noteorigin.ui

import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.animation.SharedTransitionScope
import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.origin.noteorigin.data.DayNote
import org.origin.noteorigin.data.Store
import kotlinx.coroutines.launch
import org.origin.noteorigin.ui.theme.AppType
import org.origin.noteorigin.ui.theme.GlassCard
import org.origin.noteorigin.ui.theme.MassBlock
import java.time.YearMonth

/**
 * 笔记枢纽：月历 + 当日笔记同屏，增删改就地完成。
 */
@Composable
fun NotesHub(
    store: Store,
    shared: SharedTransitionScope,
    av: AnimatedVisibilityScope,
    onEditNote: (DayNote?) -> Unit,
) {
    val cs = MaterialTheme.colorScheme
    var month by remember { mutableStateOf(YearMonth.now()) }
    var selected by remember { mutableStateOf(java.time.LocalDate.now().toString()) }
    var notes by remember { mutableStateOf(listOf<DayNote>()) }
    var marked by remember { mutableStateOf(setOf<String>()) }
    var revision by remember { mutableIntStateOf(0) }
    val scope = rememberCoroutineScope()

    fun key(m: YearMonth) = "%04d-%02d".format(m.year, m.monthValue)

    LaunchedEffect(month, selected, revision) {
        marked = store.noteDatesOfMonth(key(month))
        notes = store.notesOfDate(selected)
    }

    Column(Modifier.fillMaxSize()) {
        // 顶栏：月切换
        Row(
            Modifier.fillMaxWidth().padding(
                top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding() + 12.dp,
                start = 20.dp, end = 12.dp,
            ),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("笔记", fontSize = 26.sp, fontWeight = FontWeight.Bold, color = cs.onSurface, modifier = Modifier.weight(1f))
            Text("${month.year}年${month.monthValue}月", fontSize = AppType.meta, color = cs.onSurfaceVariant)
            Text("‹", fontSize = 24.sp, color = cs.onSurfaceVariant,
                modifier = Modifier.clickable { month = month.minusMonths(1); selected = key0(month) }.padding(6.dp))
            Text("›", fontSize = 24.sp, color = cs.onSurfaceVariant,
                modifier = Modifier.clickable { month = month.plusMonths(1); selected = key0(month) }.padding(6.dp))
        }

        LazyColumn(Modifier.fillMaxSize(), contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = 120.dp)) {
            // 月历：排版驱动的Metro格子
            item {
                with(shared) {
                    MassBlock(
                        Modifier
                            .padding(horizontal = 20.dp, vertical = 12.dp)
                            .fillMaxWidth()
                            .sharedElement(rememberSharedContentState("feature"), av),
                        tonal = cs.surfaceContainer,
                    ) {
                        Column(Modifier.padding(12.dp)) {
                            Row(Modifier.fillMaxWidth()) {
                                listOf("一", "二", "三", "四", "五", "六", "日").forEach {
                                    Text(
                                        it, fontSize = 10.sp, letterSpacing = 2.sp,
                                        color = cs.onSurfaceVariant,
                                        modifier = Modifier.weight(1f), textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                                    )
                                }
                            }
                            val lead = month.atDay(1).dayOfWeek.value - 1
                            val days = month.lengthOfMonth()
                            val today = java.time.LocalDate.now().toString()
                            var d = 1 - lead
                            while (d <= days) {
                                Row(Modifier.fillMaxWidth()) {
                                    for (i in 0 until 7) {
                                        val valid = d in 1..days
                                        val ds = if (valid) "%04d-%02d-%02d".format(month.year, month.monthValue, d) else ""
                                        val isSel = ds == selected
                                        val isToday = ds == today
                                        Box(Modifier.weight(1f).aspectRatio(1f), contentAlignment = Alignment.Center) {
                                            if (valid) {
                                                Box(
                                                    Modifier
                                                        .fillMaxSize()
                                                        .padding(3.dp)
                                                        .background(
                                                            when {
                                                                isSel -> cs.primary
                                                                isToday -> cs.primary.copy(alpha = 0.14f)
                                                                else -> androidx.compose.ui.graphics.Color.Transparent
                                                            },
                                                            RoundedCornerShape(6.dp),
                                                        )
                                                        .clickable { selected = ds },
                                                    contentAlignment = Alignment.Center,
                                                ) {
                                                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                                        Text(
                                                            "$d",
                                                            fontSize = 14.sp,
                                                            fontWeight = if (isSel || isToday) FontWeight.Bold else FontWeight.Normal,
                                                            color = if (isSel) cs.onPrimary else cs.onSurface,
                                                        )
                                                        if (ds in marked) {
                                                            Box(
                                                                Modifier
                                                                    .padding(top = 2.dp)
                                                                    .height(3.dp).fillMaxWidth(0.22f)
                                                                    .background(
                                                                        if (isSel) cs.onPrimary else cs.primary,
                                                                        RoundedCornerShape(2.dp),
                                                                    )
                                                            )
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        d++
                                    }
                                }
                            }
                        }
                    }
                }
            }

            item {
                Row(
                    Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        "$selected",
                        fontSize = AppType.meta, color = cs.onSurfaceVariant,
                        modifier = Modifier.weight(1f),
                    )
                    Text(
                        "添加",
                        fontSize = AppType.meta, color = cs.primary,
                        modifier = Modifier.clickable { onEditNote(DayNote(date = selected, content = "", createdAt = 0)) }.padding(8.dp),
                    )
                }
            }

            items(notes, key = { it.id ?: -it.createdAt }) { n ->
                GlassCard(
                    Modifier
                        .padding(horizontal = 20.dp, vertical = 6.dp)
                        .fillMaxWidth()
                        .animateContentSize()
                        .clickable { onEditNote(n) },
                ) {
                    Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            n.content,
                            fontSize = AppType.body, color = cs.onSurface,
                            modifier = Modifier.weight(1f),
                            maxLines = 3,
                            overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                        )
                        Text("删", fontSize = AppType.meta, color = cs.onSurfaceVariant,
                            modifier = Modifier.clickable {
                                scope.launch {
                                    store.deleteNote(n.id ?: return@launch)
                                    revision++
                                }
                            }.padding(6.dp))
                    }
                }
            }

            if (notes.isEmpty()) {
                item {
                    Text(
                        "这一天还没有笔记",
                        fontSize = AppType.meta, color = cs.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 24.dp, vertical = 16.dp),
                    )
                }
            }
        }
    }
}

private fun key0(m: YearMonth): String = "%04d-%02d-01".format(m.year, m.monthValue)

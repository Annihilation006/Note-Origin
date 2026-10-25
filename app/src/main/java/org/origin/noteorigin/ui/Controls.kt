@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package org.origin.noteorigin.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import org.origin.noteorigin.ui.theme.Forms
import org.origin.noteorigin.ui.theme.Motion

/**
 * 自绘控件族：按同一材质配方（M3角色色+统一形状+排版驱动）绘制，
 * 不用默认外观。
 */

/** Apple HIG式分段控件：滑动指示块 + 排版层级 */
@Composable
fun SegmentedControl(
    options: List<String>,
    selected: Int,
    modifier: Modifier = Modifier,
    onSelect: (Int) -> Unit,
) {
    val cs = MaterialTheme.colorScheme
    androidx.compose.foundation.layout.BoxWithConstraints(modifier.fillMaxWidth().height(40.dp)) {
        val segWidth = maxWidth / options.size
        Box(
            Modifier
                .fillMaxWidth()
                .background(cs.surfaceContainerHighest, RoundedCornerShape(Forms.pillCorner)),
        ) {
            val idx by animateDpAsState(
                targetValue = segWidth * selected,
                animationSpec = tween(Motion.normal, easing = Motion.emphasized),
                label = "seg",
            )
            Box(
                Modifier
                    .offset(x = idx + 3.dp)
                    .padding(vertical = 3.dp)
                    .width(segWidth - 6.dp)
                    .height(34.dp)
                    .background(cs.surface, RoundedCornerShape(Forms.pillCorner))
            )
            Row(Modifier.fillMaxWidth()) {
                options.forEachIndexed { i, opt ->
                    Box(
                        Modifier.weight(1f).clickable { onSelect(i) },
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            opt,
                            color = if (i == selected) cs.onSurface else cs.onSurfaceVariant,
                            fontWeight = if (i == selected) FontWeight.SemiBold else FontWeight.Normal,
                            fontSize = 13.sp,
                        )
                    }
                }
            }
        }
    }
}

/** Metro Pivot：大字页签 + 滑移短横线 */
@Composable
fun PivotTabs(
    tabs: List<String>,
    selected: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val cs = MaterialTheme.colorScheme
    Column(modifier = modifier.fillMaxWidth()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp)) {
            tabs.forEachIndexed { i, t ->
                Box(
                    Modifier
                        .clickable { onSelect(i) }
                        .padding(end = 22.dp, top = 6.dp, bottom = 8.dp),
                ) {
                    Column(horizontalAlignment = Alignment.Start) {
                        Text(
                            t,
                            fontSize = if (i == selected) 19.sp else 15.sp,
                            fontWeight = if (i == selected) FontWeight.Bold else FontWeight.Medium,
                            color = if (i == selected) cs.onSurface else cs.onSurfaceVariant,
                        )
                        val w by animateDpAsState(
                            targetValue = if (i == selected) 26.dp else 0.dp,
                            animationSpec = tween(Motion.fast, easing = Motion.emphasized),
                            label = "pivotline",
                        )
                        Box(
                            Modifier
                                .padding(top = 4.dp)
                                .width(w)
                                .height(3.dp)
                                .background(cs.primary, RoundedCornerShape(2.dp))
                        )
                    }
                }
            }
        }
    }
}

enum class InfoSeverity { info, success, error }

data class InfoBarMsg(val text: String, val severity: InfoSeverity = InfoSeverity.info)

/** Fluent InfoBar式全局反馈条 */
@Composable
fun InfoBarHost(msg: InfoBarMsg?, onShown: () -> Unit, modifier: Modifier = Modifier) {
    val cs = MaterialTheme.colorScheme
    LaunchedEffect(msg) {
        if (msg != null) {
            delay(2400)
            onShown()
        }
    }
    AnimatedVisibility(
        visible = msg != null,
        enter = slideInVertically(tween(240, easing = Motion.emphasized)) { -it } + fadeIn(tween(Motion.fast)),
        exit = slideOutVertically(tween(Motion.fast)) { -it } + fadeOut(tween(Motion.fast)),
        modifier = modifier,
    ) {
        val (bg, fg, dot) = when (msg?.severity) {
            InfoSeverity.success -> Triple(cs.primaryContainer, cs.onPrimaryContainer, cs.primary)
            InfoSeverity.error -> Triple(cs.errorContainer, cs.onErrorContainer, cs.error)
            else -> Triple(cs.secondaryContainer, cs.onSecondaryContainer, cs.secondary)
        }
        Surface(
            color = bg,
            contentColor = fg,
            shape = RoundedCornerShape(Forms.blockCorner),
            tonalElevation = 0.dp,
            shadowElevation = 2.dp,
        ) {
            Row(Modifier.padding(horizontal = 14.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(8.dp).background(dot, CircleShape))
                Text(
                    msg?.text ?: "",
                    Modifier.padding(start = 8.dp),
                    fontSize = 13.sp,
                )
            }
        }
    }
}

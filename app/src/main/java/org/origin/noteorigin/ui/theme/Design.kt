package org.origin.noteorigin.ui.theme

import android.provider.Settings
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.platform.LocalDensity

/**
 * 全局材质体系。四类表面 + 一档形状语言 + 一套动效参数，所有组件从这里取值。
 * 配方：每个可见组件至少叠加两种属性（M3角色 / 环境染色 / 玻璃边缘 / 排版重量）。
 */

object Motion {
    val fast = 180
    val normal = 320
    val slow = 560
    val emphasized = CubicBezierEasing(0.2f, 0f, 0f, 1f)
    val standard = CubicBezierEasing(0.4f, 0f, 0.2f, 1f)
}

// 薰衣草绿，S-以下无动态取色时的种子与强调
val LavenderSeed = Color(0xFF8AB597)

object Forms {
    val blockCorner = 6.dp   // 色块的直率几何
    val cardCorner = 18.dp   // 玻璃/环境面的圆角
    val pillCorner = 999.dp
}

@Composable
fun reduceMotion(): Boolean {
    val ctx = LocalContext.current
    return try {
        Settings.Global.getFloat(
            ctx.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f
        ) == 0f
    } catch (_: Exception) {
        false
    }
}

@Composable
fun NoteOriginTheme(dark: Boolean, content: @Composable () -> Unit) {
    val ctx = LocalContext.current
    val scheme = if (android.os.Build.VERSION.SDK_INT >= 31) {
        if (dark) dynamicDarkColorScheme(ctx) else dynamicLightColorScheme(ctx)
    } else {
        val base = if (dark) darkColorScheme() else lightColorScheme()
        // 低版本用薰衣草绿种子派生，避免整包硬编码颜色
        val seeded = if (dark) darkColorScheme(primary = LavenderSeed) else lightColorScheme(primary = LavenderSeed)
        seeded.copy(surface = base.surface, background = base.background)
    }
    MaterialTheme(
        colorScheme = scheme,
        typography = AppType.material(),
        content = content,
    )
}

/** 排版驱动层级：一套字号档位，全局不越级 */
object AppType {
    val display = 42.sp
    val feature = 21.sp
    val section = 15.sp
    val body = 15.sp
    val meta = 12.sp
    val figure = 25.sp

    // 字体文件（MiSans/HarmonyOS Sans）合法包可得分发源在此网络不可达，
    // 先用系统默认；res/font 放入文件后在此切 FontFamily 即可，UI 不用动
    @Composable
    fun material() = MaterialTheme.typography
}

/**
 * Mica式环境染色面：容器色 + 极轻的取色渐变（primary→tertiary），静态不抢。
 */
@Composable
fun AmbientSurface(
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    val cs = MaterialTheme.colorScheme
    Surface(
        modifier = modifier,
        shape = androidx.compose.foundation.shape.RoundedCornerShape(Forms.cardCorner),
        color = cs.surfaceContainer.copy(alpha = 0.92f),
        contentColor = cs.onSurface,
        border = BorderStroke(
            1.dp,
            Brush.linearGradient(
                listOf(
                    cs.primary.copy(alpha = 0.10f),
                    cs.tertiary.copy(alpha = 0.14f),
                )
            )
        ),
        content = { content() },
    )
}

/**
 * 玻璃面：半透容器 + 边缘高光渐变描边。全屏同时出现的玻璃面应≤2。
 */
@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    alpha: Float = 0.55f,
    content: @Composable () -> Unit,
) {
    val cs = MaterialTheme.colorScheme
    val edge = cs.onSurface
    Surface(
        modifier = modifier,
        shape = androidx.compose.foundation.shape.RoundedCornerShape(Forms.cardCorner),
        color = cs.surfaceContainerHighest.copy(alpha = alpha),
        contentColor = cs.onSurface,
        border = BorderStroke(
            1.dp,
            Brush.linearGradient(
                listOf(
                    edge.copy(alpha = 0.28f),
                    edge.copy(alpha = 0.04f),
                    edge.copy(alpha = 0.16f),
                ),
                start = Offset.Zero,
                end = Offset.Infinite,
            )
        ),
        content = { content() },
    )
}

/**
 * Metro色块：直角、实色、排版驱动。叠环境染色属性：容器色仍取自scheme角色。
 */
@Composable
fun MassBlock(
    modifier: Modifier = Modifier,
    tonal: Color = MaterialTheme.colorScheme.surfaceContainerHighest,
    corner: Dp = Forms.blockCorner,
    content: @Composable () -> Unit,
) {
    Surface(
        modifier = modifier,
        shape = androidx.compose.foundation.shape.RoundedCornerShape(corner),
        color = tonal,
        contentColor = MaterialTheme.colorScheme.onSurface,
        content = { content() },
    )
}

/**
 * 环境流动：仅氛围区（今日开场）允许。很慢的径向色相漂移，
 * reduceMotion时静止为静态渐变。
 */
@Composable
fun AmbientFlow(modifier: Modifier = Modifier) {
    val cs = MaterialTheme.colorScheme
    val rm = reduceMotion()
    val transition = rememberInfiniteTransition(label = "ambient")
    val phase by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 26_000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart,
        ),
        label = "phase",
    )
    Canvas(modifier = modifier) {
        val p = if (rm) 0.35f else phase
        drawAmbient(p, cs.primary, cs.tertiary, cs.surface)
    }
}

private fun DrawScope.drawAmbient(phase: Float, primary: Color, tertiary: Color, base: Color) {
    drawRect(base)
    val w = size.width
    val h = size.height
    val sweep = phase * 2f * Math.PI.toFloat()
    val c1 = Offset(w * (0.30f + 0.18f * kotlin.math.sin(sweep)), h * (0.28f + 0.12f * kotlin.math.cos(sweep)))
    val c2 = Offset(w * (0.74f + 0.14f * kotlin.math.cos(sweep * 0.8f)), h * (0.66f + 0.16f * kotlin.math.sin(sweep * 1.1f)))
    drawCircle(
        brush = Brush.radialGradient(
            colors = listOf(primary.copy(alpha = 0.20f), Color.Transparent),
            center = c1, radius = w * 0.75f,
        ),
        radius = w * 0.75f, center = c1,
    )
    drawCircle(
        brush = Brush.radialGradient(
            colors = listOf(tertiary.copy(alpha = 0.16f), Color.Transparent),
            center = c2, radius = w * 0.65f,
        ),
        radius = w * 0.65f, center = c2,
    )
}


/** 按压反馈：按下缩到0.97（慢些），松开弹回（快些），不对称才像物理 */
@Composable
fun Modifier.pressScale(interaction: androidx.compose.foundation.interaction.MutableInteractionSource): Modifier {
    val pressed by interaction.collectIsPressedAsState()
    val scale by androidx.compose.animation.core.animateFloatAsState(
        targetValue = if (pressed) 0.97f else 1f,
        animationSpec = if (pressed)
            androidx.compose.animation.core.tween(160, easing = Motion.standard)
        else
            androidx.compose.animation.core.spring(dampingRatio = 0.55f, stiffness = 900f),
        label = "press",
    )
    return this.then(Modifier.graphicsLayer { scaleX = scale; scaleY = scale })
}

/** 图表配色：从scheme的三个彩色角色做明度/色相轮转派生，不引入外部色 */
fun chartPalette(cs: androidx.compose.material3.ColorScheme, n: Int): List<Color> {
    if (n <= 0) return emptyList()
    val seeds = listOf(cs.primary, cs.tertiary, cs.secondary, cs.primary, cs.tertiary, cs.secondary)
    return List(n) { i ->
        val s = seeds[i % seeds.size]
        val shift = (i / seeds.size) * 0.12f
        s.copy(alpha = 1f).lerpTo(androidx.compose.ui.graphics.Color.Black, shift * 0.0f)
            .copy(alpha = 1f - shift)
    }
}

private fun Color.lerpTo(other: Color, t: Float): Color =
    Color(
        red = red + (other.red - red) * t,
        green = green + (other.green - green) * t,
        blue = blue + (other.blue - blue) * t,
        alpha = alpha + (other.alpha - alpha) * t,
    )

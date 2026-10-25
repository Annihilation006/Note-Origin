package org.origin.noteorigin

import android.os.Bundle
import android.content.pm.ApplicationInfo
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.ExperimentalSharedTransitionApi
import androidx.compose.animation.SharedTransitionLayout
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SmallFloatingActionButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.origin.noteorigin.data.DayNote
import org.origin.noteorigin.data.Store
import org.origin.noteorigin.data.Txn
import org.origin.noteorigin.ui.AddTxnSheet
import org.origin.noteorigin.ui.InfoBarHost
import org.origin.noteorigin.ui.InfoBarMsg
import org.origin.noteorigin.ui.InfoSeverity
import org.origin.noteorigin.ui.LedgerHub
import org.origin.noteorigin.ui.NoteEditSheet
import org.origin.noteorigin.ui.NotesHub
import org.origin.noteorigin.ui.SettingsSheet
import org.origin.noteorigin.ui.TodayHub
import org.origin.noteorigin.ui.theme.Motion
import org.origin.noteorigin.ui.theme.NoteOriginTheme
import org.origin.noteorigin.ui.theme.reduceMotion

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val release = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) == 0
        if (release) {
            Guard.run(applicationContext)
        }
        setContent {
            NoteOriginTheme(dark = isSystemInDarkTheme()) {
                Root()
            }
        }
    }
}

/** 三个目的地：今日 / 笔记 / 账本。设置走今日页内Sheet入口 */
@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
private fun Root() {
    val ctx = LocalContext.current
    val store = remember { Store(ctx) }
    LaunchedEffect(Unit) { store.bootstrap() }

    var tab by remember { mutableIntStateOf(0) }
    var info by remember { mutableStateOf<InfoBarMsg?>(null) }
    var addTxn by remember { mutableStateOf<Txn?>(null) }
    var addTxnOpen by remember { mutableStateOf(false) }
    var noteEdit by remember { mutableStateOf<DayNote?>(null) }
    var noteOpen by remember { mutableStateOf(false) }
    var settingsOpen by remember { mutableStateOf(false) }

    val rm = reduceMotion()

    fun notify(text: String, sev: InfoSeverity = InfoSeverity.info) {
        info = InfoBarMsg(text, sev)
    }

    Scaffold(
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = tab == 0, onClick = { tab = 0 },
                    icon = { Text("今", fontSize = 18.sp) }, label = { Text("今日") },
                )
                NavigationBarItem(
                    selected = tab == 1, onClick = { tab = 1 },
                    icon = { Text("笔", fontSize = 18.sp) }, label = { Text("笔记") },
                )
                NavigationBarItem(
                    selected = tab == 2, onClick = { tab = 2 },
                    icon = { Text("账", fontSize = 18.sp) }, label = { Text("账本") },
                )
            }
        },
    ) { pad ->
        Box(Modifier.fillMaxSize().padding(pad)) {
            SharedTransitionLayout {
                AnimatedContent(
                    targetState = tab,
                    transitionSpec = {
                        if (rm) {
                            fadeIn(tween(Motion.fast)) togetherWith fadeOut(tween(Motion.fast))
                        } else {
                            val dir = if (targetState > initialState) 1 else -1
                            (fadeIn(tween(Motion.normal, easing = Motion.emphasized)) +
                                slideInHorizontally(tween(Motion.normal, easing = Motion.emphasized)) { it / 8 * dir }) togetherWith
                                (fadeOut(tween(Motion.fast)) + slideOutHorizontally(tween(Motion.fast)) { -it / 8 * dir })
                        }
                    },
                    label = "hub",
                ) { t ->
                    when (t) {
                        0 -> TodayHub(
                            store = store,
                            shared = this@SharedTransitionLayout,
                            av = this@AnimatedContent,
                            onOpenNotes = { tab = 1 },
                            onOpenLedger = { tab = 2 },
                            onWriteNote = { d ->
                                noteEdit = DayNote(date = d, content = "", createdAt = 0)
                                noteOpen = true
                            },
                            onOpenSettings = { settingsOpen = true },
                        )
                        1 -> NotesHub(
                            store = store,
                            shared = this@SharedTransitionLayout,
                            av = this@AnimatedContent,
                            onEditNote = { n ->
                                noteEdit = n
                                noteOpen = true
                            },
                        )
                        else -> LedgerHub(
                            store = store,
                            shared = this@SharedTransitionLayout,
                            av = this@AnimatedContent,
                            onEditTxn = { txn ->
                                addTxn = txn
                                addTxnOpen = true
                            },
                            onInfo = { text, sev -> notify(text, sev) },
                        )
                    }
                }
            }

            // 全局反馈条（Fluent InfoBar位）
            Column(Modifier.align(Alignment.TopCenter).padding(top = 8.dp)) {
                InfoBarHost(msg = info, onShown = { info = null })
            }

            // 账本页直达"记一笔"的停靠钮
            if (tab == 2) {
                SmallFloatingActionButton(
                    onClick = {
                        addTxn = null
                        addTxnOpen = true
                    },
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(20.dp),
                ) {
                    Text("+", fontSize = 22.sp)
                }
            }
        }
    }

    if (addTxnOpen) {
        AddTxnSheet(
            store = store,
            editing = addTxn,
            onDone = { t, s -> notify(t, s) },
            onDismiss = { addTxnOpen = false },
        )
    }
    if (noteOpen) {
        noteEdit?.let { n ->
            NoteEditSheet(
                store = store,
                editing = n,
                onDone = { t, s -> notify(t, s) },
                onDismiss = { noteOpen = false },
            )
        }
    }
    if (settingsOpen) {
        SettingsSheet(
            ctx = ctx,
            store = store,
            onDone = { t, s -> notify(t, s) },
            onDismiss = { settingsOpen = false },
        )
    }
}

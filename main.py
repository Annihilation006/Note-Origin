import os
import ctypes
import ctypes.util
import asyncio
import threading
import traceback

import httpx
from kivy.utils import platform
from kivy.clock import mainthread
from kivy.lang import Builder
from kivy.logger import Logger
from kivy.core.window import Window
from kivy.storage.jsonstore import JsonStore
from kivy.uix.label import Label

from kivymd.app import MDApp
from kivymd.uix.dialog import MDDialog
from kivymd.uix.button import MDRaisedButton
from kivymd.uix.textfield import MDTextField
from kivymd.uix.pickers import MDDatePicker

KV = '''
MDScreen:
    MDBoxLayout:
        orientation: "vertical"
        MDTopAppBar:
            title: "Note Origin"
            right_action_items: [["cog", lambda x: app.show_settings()], ["calendar", lambda x: app.show_calendar()]]
        MDBoxLayout:
            padding: "20dp"
            MDLabel:
                id: content
                text: "Select a date to decrypt..."
                halign: "center"
                theme_text_color: "Primary"
        MDCard:
            size_hint: (0.9, None)
            height: "120dp"
            pos_hint: {"center_x": .5}
            padding: "15dp"
            MDLabel:
                id: ai_box
                text: "AI Insight will appear here..."
                theme_text_color: "Secondary"
'''

NATIVE_ERR = None  # 原生库加载失败的原因，会显示在界面上


def _load_libc():
    names = ["libc.so", "libc.so.6"]
    try:
        found = ctypes.util.find_library("c")
        if found:
            names.append(found)
    except Exception:
        pass
    for name in names:
        try:
            libc = ctypes.CDLL(name)
            libc.free.argtypes = [ctypes.c_void_p]
            libc.free.restype = None
            return libc
        except (OSError, AttributeError):
            continue
    return None


def _load_native_lib():
    """依次尝试加载 liblogic.so，全部失败返回 None。"""
    global NATIVE_ERR
    candidates = []

    if platform == 'android':
        # add_libs 打进 APK 的 .so 在 nativeLibraryDir 里，这是最可靠的路径
        try:
            from jnius import autoclass
            activity = autoclass('org.kivy.android.PythonActivity').mActivity
            native_dir = activity.getApplicationInfo().nativeLibraryDir
            candidates.append(os.path.join(native_dir, 'liblogic.so'))
        except Exception as e:
            NATIVE_ERR = f"nativeLibraryDir lookup failed: {e}"

    candidates.append('liblogic.so')
    candidates.append(os.path.abspath('./liblogic.so'))

    errors = []
    for path in candidates:
        try:
            lib = ctypes.CDLL(path)
            fn = lib.execute_data_purge  # 符号不存在会抛 AttributeError
            fn.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
            fn.restype = ctypes.c_void_p
            return lib
        except (OSError, AttributeError) as e:
            errors.append(f"{path}: {e}")

    msg = "\n".join(errors)
    NATIVE_ERR = f"{NATIVE_ERR}\n{msg}" if NATIVE_ERR else msg
    return None


NATIVE_LIB = _load_native_lib()
LIBC = _load_libc()


class NoteOriginApp(MDApp):

    def build(self):
        self.theme_cls.theme_style = "Light"
        self.store = JsonStore(os.path.join(self.user_data_dir, "secure_config.json"))
        try:
            return Builder.load_string(KV)
        except Exception:
            err = traceback.format_exc()
            Logger.error("NoteOrigin build: " + err)
            return Label(
                text="Startup failed:\n" + err,
                font_size="12sp",
                halign="left",
                valign="top",
                text_size=(Window.width - 40, None),
            )

    def show_settings(self):
        curr = self.store.get('api')['key'] if self.store.exists('api') else ""
        self.key_input = MDTextField(text=curr, hint_text="SiliconFlow API Key")
        self.dialog = MDDialog(
            title="Settings",
            type="custom",
            content_cls=self.key_input,
            buttons=[MDRaisedButton(text="SAVE", on_release=self.save_key)],
        )
        self.dialog.open()

    def save_key(self, *args):
        self.store.put('api', key=self.key_input.text)
        self.dialog.dismiss()

    def show_calendar(self):
        picker = MDDatePicker()
        picker.bind(on_save=self.on_date_selected)
        picker.open()

    def on_date_selected(self, instance, value, date_range):
        content = self.root.ids.content
        date_str = value.strftime("%Y-%m-%d")

        if NATIVE_LIB is None:
            content.text = "Native core not loaded:\n" + (NATIVE_ERR or "unknown error")
            return

        try:
            ptr = NATIVE_LIB.execute_data_purge(date_str.encode("utf-8"), b"zh")
            if not ptr:
                content.text = "Native core returned NULL"
                return

            raw = ctypes.string_at(ptr).decode("utf-8", errors="replace")
            if LIBC is not None:
                LIBC.free(ptr)

            real_note = "".join(chr(ord(c) ^ 0x07) for c in raw)
            content.text = f"Decrypted: {real_note}"

            threading.Thread(target=self._ask_worker, args=(real_note,), daemon=True).start()
        except Exception:
            content.text = "Decrypt error:\n" + traceback.format_exc()[-400:]

    def _ask_worker(self, note_text):
        try:
            asyncio.run(self.ask_qwen(note_text))
        except Exception:
            Logger.error("NoteOrigin AI worker: " + traceback.format_exc())

    async def ask_qwen(self, note_text):
        cfg = self.store.get('api') if self.store.exists('api') else {}
        api_key = cfg.get('key', '')
        if not api_key:
            self.update_ai_ui("API key not set (tap the gear icon)")
            return

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                r = await client.post(
                    "https://api.siliconflow.cn/v1/chat/completions",
                    headers={"Authorization": f"Bearer {api_key}"},
                    json={
                        "model": "Qwen/Qwen2.5-7B-Instruct",
                        "messages": [{"role": "user", "content": note_text}],
                    },
                )
                r.raise_for_status()
                summary = r.json()['choices'][0]['message']['content']
                self.update_ai_ui(summary)
        except Exception as e:
            self.update_ai_ui(f"AI request failed: {e}")

    @mainthread
    def update_ai_ui(self, text):
        self.root.ids.ai_box.text = f"Qwen: {text}"


NoteOriginApp().run()

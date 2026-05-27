import ctypes, ctypes.util, httpx, asyncio, threading, os
from kivy.utils import platform
from kivymd.app import MDApp
from kivy.lang import Builder
from kivy.clock import Clock, mainthread
from kivy.storage.jsonstore import JsonStore
from kivymd.uix.dialog import MDDialog
from kivymd.uix.button import MDRaisedButton
from kivymd.uix.textfield import MDTextField

# 加载 Swift 内核与 C 标准库
# 修复：Android 上 .so 不在当前目录，需要动态定位
def _load_lib():
    if platform == 'android':
        # p4a 打包后 .so 在应用私有目录
        base = os.path.dirname(os.path.abspath(__file__))
        candidates = [
            os.path.join(base, "liblogic.so"),
            "/data/data/org.origin.noteorigin/files/app/liblogic.so",
        ]
        for p in candidates:
            if os.path.exists(p):
                return ctypes.CDLL(p)
        return None
    else:
        return ctypes.CDLL("./liblogic.so")

try:
    lib = _load_lib()
    if lib:
        lib.execute_data_purge.restype = ctypes.c_char_p
    libc = ctypes.CDLL(ctypes.util.find_library("c"))
except Exception as e:
    lib = None
    libc = None
    print(f"[WARN] Failed to load liblogic.so: {e}")

KV = '''
MDScreen:
    md_bg_color: self.theme_cls.backgroundColor
    MDBoxLayout:
        orientation: "vertical"
        MDTopAppBar:
            title: "Note Origin"
            md_bg_color: self.theme_cls.primary_color
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
            md_bg_color: self.theme_cls.primary_color[0:3] + [0.1]
            MDLabel:
                id: ai_box
                text: "AI Insight will appear here..."
                theme_text_color: "Secondary"
'''

class NoteOriginApp(MDApp):
    store = JsonStore('secure_config.json')

    def build(self):
        self.theme_cls.theme_style = "Dark"
        if platform == 'android':
            self.sync_monet()
        return Builder.load_string(KV)

    @mainthread
    def sync_monet(self):
        """动态提取 Android 壁纸颜色"""
        try:
            from jnius import autoclass
            Activity = autoclass('org.kivy.android.PythonActivity').mActivity
            WM = autoclass('android.app.WallpaperManager').getInstance(Activity)
            colors = WM.getWallpaperColors(1)
            if colors:
                c = colors.getPrimaryColor()
                self.theme_cls.primary_color = [c.red(), c.green(), c.blue(), 1]
        except Exception as e:
            print(f"[WARN] Monet sync failed: {e}")

    def show_settings(self):
        curr_key = self.store.get('api')['key'] if self.store.exists('api') else ""
        self.key_input = MDTextField(text=curr_key, hint_text="SiliconFlow API Key")
        self.dialog = MDDialog(title="Safety Settings", type="custom", content_cls=self.key_input,
                               buttons=[MDRaisedButton(text="SAVE", on_release=self.save_key)])
        self.dialog.open()

    def save_key(self, *args):
        self.store.put('api', key=self.key_input.text)
        self.dialog.dismiss()

    def show_calendar(self):
        from kivymd.uix.pickers import MDDatePicker
        picker = MDDatePicker()
        picker.bind(on_save=self.on_date_selected)
        picker.open()

    def on_date_selected(self, instance, value, date_range):
        date_str = value.strftime("%Y-%m-%d")
        if not lib:
            self.root.ids.content.text = "Error: native library not loaded."
            return
        # 调用 Swift 内核并手动释放内存
        raw_ptr = lib.execute_data_purge(date_str.encode(), b"zh")
        if raw_ptr:
            res_str = ctypes.string_at(raw_ptr).decode()
            if libc:
                libc.free(raw_ptr)
            # XOR 还原
            real_note = "".join([chr(ord(c) ^ 0x07) for c in res_str])
            self.root.ids.content.text = f"Decrypted: {real_note}"
            # 修复：asyncio.run() 会阻塞主线程，改用子线程
            threading.Thread(
                target=lambda: asyncio.run(self.ask_qwen(real_note)),
                daemon=True
            ).start()

    async def ask_qwen(self, note_text):
        if not self.store.exists('api'):
            return
        api_key = self.store.get('api')['key']
        async with httpx.AsyncClient() as client:
            try:
                r = await client.post(
                    "https://api.siliconflow.cn/v1/chat/completions",
                    headers={"Authorization": f"Bearer {api_key}"},
                    json={"model": "Qwen/Qwen2.5-7B-Instruct", "messages": [{"role": "user", "content": note_text}]},
                    timeout=12.0
                )
                summary = r.json()['choices'][0]['message']['content']
                Clock.schedule_once(lambda dt: self.update_ai_ui(summary))
            except Exception as e:
                print(f"[WARN] AI request failed: {e}")

    def update_ai_ui(self, text):
        self.root.ids.ai_box.text = f"Qwen: {text}"

NoteOriginApp().run()
            size_hint: (0.9, None)
            height: "120dp"
            pos_hint: {"center_x": .5}
            padding: "15dp"
            md_bg_color: self.theme_cls.primary_color[0:3] + [0.1]
            MDLabel:
                id: ai_box
                text: "AI Insight will appear here..."
                theme_text_color: "Secondary"
'''

class NoteOriginApp(MDApp):
    store = JsonStore('secure_config.json')

    def build(self):
        self.theme_cls.theme_style = "Dark"
        if platform == 'android': self.sync_monet()
        return Builder.load_string(KV)

    @mainthread
    def sync_monet(self):
        """动态提取 Android 壁纸颜色"""
        try:
            from jnius import autoclass
            Activity = autoclass('org.kivy.android.PythonActivity').mActivity
            WM = autoclass('android.app.WallpaperManager').getInstance(Activity)
            colors = WM.getWallpaperColors(1)
            if colors:
                c = colors.getPrimaryColor()
                # 归一化处理
                self.theme_cls.primary_color = [c.red(), c.green(), c.blue(), 1]
        except: pass

    def show_settings(self):
        curr_key = self.store.get('api')['key'] if self.store.exists('api') else ""
        self.key_input = MDTextField(text=curr_key, hint_text="SiliconFlow API Key")
        self.dialog = MDDialog(title="Safety Settings", type="custom", content_cls=self.key_input,
                               buttons=[MDRaisedButton(text="SAVE", on_release=self.save_key)])
        self.dialog.open()

    def save_key(self, *args):
        self.store.put('api', key=self.key_input.text)
        self.dialog.dismiss()

    def show_calendar(self):
        from kivymd.uix.pickers import MDDatePicker
        picker = MDDatePicker()
        picker.bind(on_save=self.on_date_selected)
        picker.open()

    def on_date_selected(self, instance, value, date_range):
        date_str = value.strftime("%Y-%m-%d")
        # 1. 调用 Swift 内核并手动释放内存
        raw_ptr = lib.execute_data_purge(date_str.encode(), b"zh")
        if raw_ptr:
            res_str = ctypes.string_at(raw_ptr).decode()
            libc.free(raw_ptr) 
            # XOR 还原
            real_note = "".join([chr(ord(c) ^ 0x07) for c in res_str])
            self.root.ids.content.text = f"Decrypted: {real_note}"
            # 2. 异步 AI 请求
            Clock.schedule_once(lambda dt: asyncio.run(self.ask_qwen(real_note)))

    async def ask_qwen(self, note_text):
        if not self.store.exists('api'): return
        api_key = self.store.get('api')['key']
        async with httpx.AsyncClient() as client:
            try:
                r = await client.post(
                    "https://api.siliconflow.cn/v1/chat/completions",
                    headers={"Authorization": f"Bearer {api_key}"},
                    json={"model": "Qwen/Qwen2.5-7B-Instruct", "messages": [{"role": "user", "content": note_text}]},
                    timeout=12.0
                )
                summary = r.json()['choices'][0]['message']['content']
                Clock.schedule_once(lambda dt: self.update_ai_ui(summary))
            except: pass

    def update_ai_ui(self, text):
        self.root.ids.ai_box.text = f"Qwen: {text}"

NoteOriginApp().run()

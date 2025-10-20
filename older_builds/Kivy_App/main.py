# main.py

import asyncio
from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.core.window import Window
from kivy.uix.screenmanager import ScreenManager, SlideTransition

from screens.dashboard_screen import DashboardScreen
from screens.settings_screen import SettingsScreen
from screens.workout_log_screen import WorkoutLogScreen
from ui.nav_bar import NavigationBar
from utils.graph_utils import save_sleep_graph
from screens.metrics_screen import MetricsScreen




Window.size = (375, 667)

class WearableApp(App):
    async def async_run(self, **kwargs):
        return await super().async_run(**kwargs)

    def build(self):
        save_sleep_graph()
        self.sm = ScreenManager(transition=SlideTransition(duration=0.3))
        self.sm.add_widget(DashboardScreen(name='dashboard'))
        self.sm.add_widget(SettingsScreen(name='settings'))
        self.sm.add_widget(WorkoutLogScreen(name='log'))
        self.sm.add_widget(MetricsScreen(name='metrics'))


        self.screen_order = ['dashboard', 'log', 'metrics', 'settings']
        root_layout = BoxLayout(orientation='vertical')
        root_layout.add_widget(self.sm)
        root_layout.add_widget(NavigationBar())
        return root_layout

    def on_start(self):
        Window.bind(on_touch_down=self._on_touch_down)
        Window.bind(on_touch_up=self._on_touch_up)
        Window.bind(on_key_down=self._on_key_down)
        self._touch_start_x = 0

    def _on_key_down(self, window, key, scancode, codepoint, modifier):
        if key == 276:  # Left arrow
            current_idx = self.screen_order.index(self.sm.current)
            if current_idx > 0:
                self.go_to_screen(self.screen_order[current_idx - 1])
        elif key == 275:  # Right arrow
            current_idx = self.screen_order.index(self.sm.current)
            if current_idx < len(self.screen_order) - 1:
                self.go_to_screen(self.screen_order[current_idx + 1])

    def _on_touch_down(self, window, touch):
        self._touch_start_x = touch.x

    def _on_touch_up(self, window, touch):
        dx = touch.x - self._touch_start_x
        if abs(dx) > 50:
            current_idx = self.screen_order.index(self.sm.current)
            if dx < 0 and current_idx < len(self.screen_order) - 1:
                self.go_to_screen(self.screen_order[current_idx + 1])
            elif dx > 0 and current_idx > 0:
                self.go_to_screen(self.screen_order[current_idx - 1])

    def go_to_screen(self, target_name):
        current_idx = self.screen_order.index(self.sm.current)
        target_idx = self.screen_order.index(target_name)
        self.sm.transition.direction = 'left' if target_idx > current_idx else 'right'
        self.sm.current = target_name


if __name__ == '__main__':
    asyncio.run(WearableApp().async_run(async_lib='asyncio'))

from kivy.uix.boxlayout import BoxLayout
from kivy.uix.button import Button
from kivy.app import App

class NavigationBar(BoxLayout):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.orientation = 'horizontal'
        self.size_hint_y = None
        self.height = 75
        self.spacing = 10
        self.padding = [10, 10]
        self.background_color = (0.8, 0.8, 0.8, 1)

        font = 'fonts/NotoEmoji-Regular.ttf'
        bg = (0.7, 0.7, 0.7, 1)

        btn_dashboard = Button(
            text='📊',
            font_size=50,
            font_name=font,
            background_color=bg
        )
        btn_log = Button(
            text='📝',
            font_size=50,
            font_name=font,
            background_color=bg
        )
        btn_metrics = Button(
            text='📈',
            font_size=50,
            font_name=font,
            background_color=bg
        )
        btn_settings = Button(
            text='⚙️',
            font_size=50,
            font_name=font,
            background_color=bg
        )

        btn_dashboard.bind(on_release=lambda x: App.get_running_app().go_to_screen('dashboard'))
        btn_log.bind(on_release=lambda x: App.get_running_app().go_to_screen('log'))
        btn_metrics.bind(on_release=lambda x: App.get_running_app().go_to_screen('metrics'))
        btn_settings.bind(on_release=lambda x: App.get_running_app().go_to_screen('settings'))

        self.add_widget(btn_dashboard)
        self.add_widget(btn_log)
        self.add_widget(btn_metrics)
        self.add_widget(btn_settings)

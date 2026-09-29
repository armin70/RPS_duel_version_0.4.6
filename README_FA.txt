RPS Duel — Physical Board + Fixed Camera Patch 0.5.0
===================================================

این پچ چهار مشکل را با هم اصلاح می‌کند:

1) GameLayout دیگر Position/Rotation/Scale زمین، Slotها، Handها یا Camera را در Runtime بازنویسی نمی‌کند.
2) BoardPlane + PlayerBoard + DealerRow + OpponentBoard زیر یک BoardPivot واقعی قرار می‌گیرند.
   بنابراین با چرخاندن BoardPivot، خود زمین، Area3Dها، CollisionShape3Dها، CardAnchorها و کارت‌ها واقعاً با هم می‌چرخند.
3) IntroCamera حرکت نمی‌کند؛ Camera3D فقط از Transform داخل Scene/Inspector استفاده می‌کند.
4) Notice اول بازی و VFX startup ضدقفل می‌شوند:
   - UnderstoodButton هنگام Pause هم Input می‌گیرد.
   - Runtime VFX یک فریم دیرتر ساخته می‌شود تا خطای "Parent node is busy setting up children" ندهد.

نصب پیشنهادی
-------------

A) کل پوشه RPS_Physical_Board_Patch_050 را داخل یک جای موقت Extract کن.

B) در CMD/PowerShell:

    python apply_project_patch.py "C:\PATH\TO\RPS_Duel_final"

این Script قبل از هر تغییر یک پوشه Backup با نام شبیه زیر داخل پروژه می‌سازد:

    _physical_board_backup_YYYYMMDD_HHMMSS

C) Godot را باز کن و Scene اصلی بازی را باز کن.

D) فایل زیر را در Script Editor باز کن:

    res://tools/physical_board_scene_setup.gd

و EditorScript را یک بار Run کن.

بعد ساختار GameLayout باید این‌طور باشد:

GameLayout
├── BoardPivot
│   ├── BoardPlane
│   ├── PlayerBoard
│   ├── DealerRow
│   └── OpponentBoard
├── PlayerHand
├── OpponentHand
├── PlayerPiles
└── OpponentPiles

از این به بعد:

- فقط BoardPivot را برای کل صفحه بازی Move / Rotate / Scale کن.
- BoardPlane را فقط برای اندازه/UV زمین تغییر بده.
- Camera3D را مستقیم در Inspector تنظیم کن.
- هیچ Scriptی نباید Camera3D را جلو/عقب ببرد.

نکته مهم
---------

پچ Main Menu و MatchController را روی فایل فعلی خود پروژه انجام می‌دهد و کل فایل را با نسخه قدیمی جایگزین نمی‌کند؛
پس تغییرات Online/Lockstep جدیدت حفظ می‌شوند.

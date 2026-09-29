# RPS Duel — Real Scene Board Cleanup

هدف این پچ این است که زمین جدید دیگر با `board_2_5d.gd` در زمان Run تنظیم نشود.

بعد از اجرا:

- `BoardVisual/GroundMap` مستقیماً داخل `main_game.tscn` منبع ظاهر زمین است.
- Position / Rotation / Pixel Size زمین داخل خود Scene ذخیره می‌شود.
- Camera FOV / Near / Far / Current داخل خود Scene ذخیره می‌شود.
- `game/board_2_5d.gd` و `.uid` آن حذف می‌شوند.
- `art/main_land/Land2.5D_V1.1.png` حفظ می‌شود.
- فایل‌های دیگر `art/main_land` فقط وقتی حذف می‌شوند که هیچ Reference واقعی در فایل‌های متنی پروژه نداشته باشند.
- اگر `game/main_game.scn` باینری قدیمی وجود داشته باشد، فقط وقتی حذف می‌شود که هیچ Reference متنی به آن پیدا نشود؛ در غیر این صورت برای ایمنی نگه داشته می‌شود.
- قبل از تغییر، یک ZIP بکاپ در پوشه‌ی بالاتر از پروژه ساخته می‌شود، نه داخل خود پروژه.

## اجرا

فایل `apply_board_scene_cleanup.py` را لازم نیست داخل پروژه نگه دارید. از Terminal/CMD اجرا کنید:

```bash
python apply_board_scene_cleanup.py "PATH_TO_RPS_Duel_final"
```

اول می‌توانید Dry Run بگیرید:

```bash
python apply_board_scene_cleanup.py "PATH_TO_RPS_Duel_final" --dry-run
```

اگر نمی‌خواهید Assetهای قدیمی `art/main_land` پاک شوند:

```bash
python apply_board_scene_cleanup.py "PATH_TO_RPS_Duel_final" --keep-old-assets
```

## بعد از اجرا

Godot را باز کنید و `game/main_game.tscn` را باز کنید.

در Scene Tree باید این را ببینید:

```text
MainGame
└── BoardVisual
    └── GroundMap
```

`GroundMap` باید بدون اجرای بازی در 3D Editor قابل مشاهده باشد. دیگر هیچ Scriptی روی `BoardVisual` لازم نیست.

`GameLayout`، `CardPlace3D`، CollisionShapeها و Markerهای Slot حذف نمی‌شوند، چون این‌ها «زمین قدیمی» نیستند؛ منطق واقعی Drop/Placement کارت‌ها هنوز به آن‌ها وابسته است. Mesh خود Slotها از قبل `visible = false` است و فقط Collision/Anchor باقی می‌ماند.

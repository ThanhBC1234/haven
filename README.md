# Bouncing Ball (Godot 4.5)

Game hackathon "Bounce Back": con lật đật (trái banh đỏ trên đế vàng) nhảy và nảy theo vật lý thật.
Copy cả thư mục đi đâu cũng chạy được. Màn chơi và nhân vật là thiết kế riêng, không lấy từ game khác.
Chữ trong game bằng tiếng Anh; ghi chú trong code bằng tiếng Việt.

## Mở và chạy

Godot 4.5 → **Import** → chọn `project.godot` → **F5**.

| Phím | Tác dụng |
|---|---|
| Giữ A (hoặc ←) | Nghiêng trái, tích lực |
| Giữ D (hoặc →) | Nghiêng phải, tích lực |
| Space, W hoặc ↑ | Nhảy theo hướng và lực đang tích (không giữ A/D thì nhảy thẳng lên) |
| Thả A/D mà không bấm nhảy | Hủy, đứng thẳng lại |
| F hoặc J | Bắn (khi có đạn). Đang giữ A/D thì bắn chéo lên theo mũi tên, không thì bắn ngang |
| R | Tự nổ, bật lại ở cờ lưu / đầu đoạn (mất 1 mạng) |
| Esc | Về menu |

## Chế độ chơi

- **Endless Run (vô tận):** ghép ngẫu nhiên các đoạn trong `scripts/segment_data.gd`, chạy mãi tới khi hết 3 mạng.
  - Điểm = quãng đường (1 ô = 1 mét) x hệ số nhân, mỗi sao +25 x hệ số nhân.
  - Hệ số nhân tăng 1 sau mỗi 4 đoạn (tối đa x5).
  - Đầu lượt chỉ ra đoạn dễ (độ khó 1); qua 3 đoạn có đoạn vừa (2); qua 7 đoạn có đoạn khó (3).
  - Chết thì bật lại ở đầu đoạn đang chơi.
  - Kỷ lục và tổng số sao được lưu vào máy (`user://bouncing_ball.cfg`).
- **Màn thường:** First Bounce, Seesaw Valley, Boss Arena (có đích, 3 sao mỗi màn). Màn đẩy thùng đã bỏ.
- Cứ 8 đoạn vô tận có một **đấu trường boss** (`BOSS_ARENA` trong `segment_data.gd`, đổi tần suất ở `BOSS_EVERY` trong `endless.gd`). Hạ boss +500 x hệ số nhân.

## Vật phẩm, súng, boss

| Thứ | Ký tự | Tác dụng |
|---|---|---|
| Trái tim | `+` | +1 mạng (tối đa 3) |
| Khiên | `h` | Đỡ 1 đòn, có vòng sáng quanh nhân vật; vỡ khiên thì được miễn sát thương 1,2 giây |
| Súng | `g` | +15 đạn; mọc lại sau 8 giây (đấu boss không bao giờ hết đạn) |
| Boss | `M` | GLOOMFANG: quả cầu quái vật **chỉ lăn trên mặt đất** (đặt `M` ngay trên mặt đất). Lăn qua lại, hiện **dấu ! đỏ** và rung lắc rồi **lao** về phía bạn, đâm tường thì **choáng** (sao vàng quay). Còn nửa máu thì đỏ lên, lăn và lao nhanh hơn. 12 máu. Cách đánh: **bắn ngang** (F / J) hoặc **nhảy lên đầu** (mỗi lần trừ 1 máu); đụng ngang thân thì bị thương |
| Cổng boss | `G` | Chặn đường, mở khi hạ boss |
| Dốc | `/` `\` `1` `2` `3` `4` | Dốc đứng lên/xuống; dốc thoải lên (1 rồi 2) và xuống (3 rồi 4). Ghép thành đồi, thung lũng |

Số chỉnh ở Inspector: boss (`scenes/objects/boss.tscn`: `Max Hp`, tốc độ lăn / lao, `Charge Every`, `Warn Time`, `Dizzy Time`, `Roam` vùng lăn), súng (`scenes/ball.tscn`:
`Shoot Cooldown`, `Max Ammo`, `Invuln After Hit`), số đạn mỗi lần nhặt (`Gun Ammo` trong `pickup.tscn`).

**Hướng dẫn trong game:** menu có nút **HOW TO PLAY** (nội dung sửa ở `HOW_TO_PLAY` trong `scripts/ui/menu.gd`); nhặt súng thì hiện "Press F or J to shoot"; ô đạn luôn ghi phím bắn; boss xuất hiện thì hiện cách đánh, dưới thanh máu boss có dòng nhắc.

**Hình pixel:** mọi hình mới (boss, đạn, tim, khiên, súng, thanh máu) vẽ bằng code từ các mảng chữ trong
`scripts/pixel_art.gd`. Sửa chữ là đổi hình. Khi có PNG: mở scene tương ứng (`boss.tscn`, `player_bullet.tscn`,
`pickup.tscn`), thêm `Sprite2D`, tắt `Show Placeholder`.

### Thêm đoạn cho chế độ vô tận

Mở `scripts/segment_data.gd`, chép một khối `{"name": ..., "difficulty": ..., "map": """..."""}` vào `SEGMENTS` rồi sửa.
Đoạn mới **tự vào vòng ngẫu nhiên**, không cần sửa code. Quy tắc (bài test tự kiểm tra):

- Cao đúng 18 hàng, đất ở 2 hàng cuối, không có tường hai bên.
- 4 cột đầu và 4 cột cuối là đất bằng, phía trên trống (để nối với đoạn khác).
- Có `O` ở cột thứ 3, hàng thứ 16 (chỗ hồi sinh).
- Không dùng thùng, nút, cửa, cờ lưu, đích, boss (`x a b d A B D K F M G`). Dùng được dốc, tim, khiên, súng.
- Bản đồ viết trong chuỗi `r"""..."""` (chuỗi thô) để dấu `\` của dốc giữ nguyên.

Chỉnh nhịp độ ở đầu `scripts/endless.gd`: `STAR_POINTS`, `SEGMENTS_PER_MULT`, `MAX_MULT`, `DIFFICULTY_STEPS`, `LIVES`.

## Cơ chế

- Giữ A/D càng lâu thì nghiêng càng nhiều; bấm nhảy thì nhảy càng mạnh và càng xa. Có mũi tên chỉ hướng và độ mạnh.
- Chỉ nhảy được khi chạm đất. Bấm nhảy sớm một chút trước khi chạm đất vẫn tính.
- Đang giữ A/D khi chạm lò xo hoặc dẫm quái thì bật chéo theo hướng đó.
- Rơi xuống thì **nảy như bóng thật**: mỗi lần nảy thấp hơn (khoảng 30%) rồi đứng yên; thân lắc lư kiểu lật đật.
- **3 mạng.** Chết thì hồi sinh ở cờ lưu. Hết mạng thì chơi lại màn.
- **Đồ vật:** quái đi tuần (dẫm từ trên thì chết, đụng ngang thì bị thương), gai, thùng gỗ, nút đạp và cửa, bệ di chuyển ngang/dọc, bập bênh, lò xo, sao (3 mỗi màn), cờ lưu, đích.

Số đo để thiết kế màn (1 ô = 32 px):

| Giữ phím | Cao | Xa |
|---|---|---|
| Bấm nhanh | 1 ô | 1 ô |
| 1/4 lực (~0,2 giây) | 2 ô | 3 ô |
| Nửa lực (~0,35 giây) | 3 ô | 7 ô |
| 3/4 lực | 4,4 ô | 12 ô |
| Đủ lực (0,7 giây) | 5 ô | 18 ô |
| Lò xo | khoảng 9 ô | |

## Sửa và thêm màn

Màn chơi vẽ bằng chữ trong `scripts/level_data.gd`, bảng ký tự ở đầu file. Sửa ký tự, F5 là thấy.

- `#` đất, `O` xuất phát, `F` đích, `*` sao, `K` cờ lưu
- `^` gai đất, `v` gai trần, `e` quái, `x` thùng, `T` lò xo, `S` bập bênh
- `a b d` nút, `A B D` cửa (nút chữ thường mở cửa chữ hoa cùng chữ)
- `===` bệ di chuyển, `>` điểm đến ngang, `|` điểm đến dọc

Thêm màn: chép một khối `{"name": ..., "map": """..."""}` trong `LEVELS` rồi sửa. Menu tự hiện màn mới.

## Chỉnh cảm giác chơi

Mở `scenes/ball.tscn`, chọn node `Ball`, sửa ở Inspector:

- `Charge Time`: giữ bao lâu thì đủ lực.
- `Min/Max Speed`: lực nhảy nhỏ nhất và lớn nhất.
- `Min/Max Tilt Deg`: góc nhảy khi bấm nhanh và khi giữ đủ lực.
- `Wobble Stiffness/Damping`: lắc lư nhanh hay chậm, mau dừng hay lâu.
- **Độ nảy**: mục **Physics Material Override → Bounce** (0.55; 0 = không nảy, 0.9 = nảy gần như mãi).
- **Độ bám**: **Friction** (0.9).

Quái, lò xo, bệ, bập bênh cũng có số chỉnh ở Inspector của scene tương ứng trong `scenes/objects/`.
Đổi phím ở `scripts/autoload/game.gd`. Trọng lực: Project Settings → Physics → 2D → Default Gravity.
Sau khi đổi lực nhảy, chạy `tests/measure.tscn` để đo lại tầm nhảy.

## Hình nhân vật và hoạt ảnh

Hình nhân vật là `assets/player.png` (16 x 32 px, một khung, nền trong suốt). Trong `scenes/ball.tscn`, node `Sprite`
cắt ảnh làm 3 phần bằng **Region**: `Head` (hàng 0-7), `Spring` (hàng 8-16), `BallPart` (hàng 17-31).
Code `scripts/ball_sprite.gd` làm chúng chuyển động: giữ phím thì lò xo nén và người ngả theo hướng,
bật nhảy thì lò xo duỗi, chạm đất thì banh bẹp (rơi càng mạnh càng bẹp), đầu lắc trễ theo quán tính.

- **Đổi hình** cùng bố cục (đầu, cổ, banh xếp dọc 16 x 32): ghi đè `assets/player.png` là xong.
- Ảnh khác kích thước: chọn từng Sprite2D con, sửa **Region → Rect** cho đúng vùng; sửa `BALL_H`, `SPRING_H` trong `ball_sprite.gd`.
- **Chỉnh độ "nảy" của hoạt ảnh** ở Inspector node `Sprite`: `Land Squash` (bẹp khi chạm đất), `Charge Compress` (lò xo nén khi giữ phím),
  `Jump Stretch` (lò xo duỗi khi nhảy), `Head Follow` (đầu lắc nhiều hay ít), `Pixel Scale` (phóng to ảnh).
- Chỉ trái banh có va chạm (vòng tròn 30 px). Đầu và lò xo chỉ là hình: chạm gai trần bằng đầu không bị thương.
- Muốn quay lại hình vẽ bằng code: ẩn node `Sprite` và bật `Show Placeholder` ở node `Ball`.

## Đồ họa từ gói miễn phí và ghi công

| Gói | File trong project | Dùng cho |
|---|---|---|
| **Dark Fantasia Forest** (tileset) | `assets/forest/forest_tiles.png`, `assets/forest/forest_decorations.png` | Đất (tự ghép mép trong `scripts/level.gd`), nấm trang trí, gạch đá của bệ di chuyển |
| **SHADOW Series - Free UI** | `assets/ui/frame_1..4.png` (khung đã phóng to x2 và tô nền tối), `assets/ui/spinner_1..6.png` | Nút, bảng, ô HUD (`scripts/ui/ui_theme.gd`), biểu tượng xoay (`scripts/ui/spinner_icon.gd`) |

Hai gói tải về **không kèm file giấy phép**. Trước khi nộp bài, mở lại trang tải (thường là itch.io) để xem
có được dùng trong game không và có cần ghi tên tác giả không. Nếu cần, thêm tên tác giả vào màn credit hoặc trang giới thiệu.

- **Đổi khung nút:** sửa `FRAME_NORMAL`, `FRAME_HOVER`, `FRAME_PRESSED`, `FRAME_PANEL` trong `ui_theme.gd`.
- **Đổi đồ trang trí:** sửa danh sách `DECOR_KINDS` trong `level.gd` (vùng hình trong `forest_decorations.png`). Tắt trang trí: bỏ tích `decorate`.
- **Đổi màu nền rừng, trăng, đom đóm:** `scripts/background.gd`.
- Thư mục `C:\game\asset-packs` là bản giải nén gốc, xóa được khi không cần.

## Thêm hình (assets)

Mỗi đồ vật đang tự vẽ hình tạm bằng code. Để thay bằng PNG:

1. Bỏ file PNG vào thư mục `assets/`.
2. Mở scene của đồ vật, ví dụ `scenes/ball.tscn` hoặc `scenes/objects/enemy.tscn`.
3. Chọn node gốc → **Add Child Node** → `Sprite2D` (hoặc `AnimatedSprite2D` nếu có nhiều khung hình), kéo PNG vào ô **Texture**.
4. Ở node gốc, bỏ tích **Show Placeholder** để tắt hình tạm.


- **Đất:** vẽ bằng `assets/forest/forest_tiles.png`. Thay bằng bộ gạch khác cùng bố cục (khối 6 x 6 ô 16 px ở góc trên trái) là đất đổi theo.
- **Nền rừng đêm:** `scripts/background.gd`.
- **Âm thanh:** bóng có tín hiệu `launched` và `hurt`. Thêm `AudioStreamPlayer` vào `scenes/play.tscn`, rồi trong `play.gd` gọi `.play()` khi các tín hiệu này phát.

## Cấu trúc

| File | Làm gì |
|---|---|
| `scripts/ball.gd` | Con lật đật: giữ để nghiêng, thả để nhảy, lắc lư, bị thương |
| `scripts/ball_sprite.gd` | Hoạt ảnh hình nhân vật: lò xo nén/giãn, banh bẹp, đầu lắc |
| `scripts/level.gd` | Dựng màn từ bản đồ chữ, vẽ đất, kênh nút/cửa |
| `scripts/level_data.gd` | Các màn thường (bản đồ chữ) |
| `scripts/segment_data.gd` | Các đoạn cho chế độ vô tận |
| `scripts/endless.gd` | Chế độ vô tận: ghép đoạn ngẫu nhiên, đấu trường boss, điểm, hệ số nhân, thua |
| `scripts/pixel_art.gd` | Hình pixel vẽ bằng code (tim, khiên, súng, đạn, boss, dấu !) |
| `scripts/objects/boss.gd`, `player_bullet.gd` | Boss lăn trên mặt đất, đạn người chơi |
| `scripts/play.gd` | Camera, mạng, sao, hồi sinh, qua màn |
| `scripts/objects/` | Quái, thùng, gai, nút, cửa, bệ, bập bênh, sao/cờ/đích/lò xo |
| `scripts/ui/` | Menu, HUD, giao diện |
| `scripts/autoload/game.gd` | Phím, chuyển cảnh, nhớ sao |

## Kiểm tra tự động

```
godot --headless --fixed-fps 60 --path . res://tests/smoke.tscn
```

Chạy 68 kiểm tra (cơ chế, quy tắc đoạn vô tận, chế độ vô tận). `tests/segments_preview.tscn` (chạy có cửa sổ) chụp toàn cảnh từng đoạn. `tests/measure.tscn` đo lại tầm nhảy sau khi chỉnh số; `tests/ball_preview.tscn` (chạy có cửa sổ) chụp ảnh phóng to nhân vật.

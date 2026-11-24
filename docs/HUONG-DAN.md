# Bouncing Ball: hướng dẫn chỉnh sửa (Godot 4.5)

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

## Chế độ Bounce Brawl (2 người)

Hai quả bóng trên một màn hình, một bàn phím. Ở menu bấm **BRAWL 2P** (hai người) hoặc **BRAWL VS BOT** (đấu với máy).
Mỗi trận bốc ngẫu nhiên một đấu trường trong `scripts/brawl_data.gd`.

| Việc | Người chơi 1 (bên trái, màu đỏ) | Người chơi 2 (bên phải, màu xanh) |
|---|---|---|
| Giữ để nghiêng trái, tích lực | A | ← |
| Giữ để nghiêng phải, tích lực | D | → |
| Nhảy (theo hướng và lực đang tích) | W | ↑ |
| Dùng vật phẩm | S | ↓ |

- **Cách ghi điểm:** dẫm đầu đối thủ (stomp), đối thủ rơi xuống vực, hoặc đối thủ chạm gai. Mỗi lần được 1 điểm.
- **Thắng:** ai đạt **5 điểm** (`WIN_SCORE` trong `scripts/brawl.gd`) trước thì thắng.
- **Hồi sinh:** bóng chết thì vỡ, sau 1,2 giây hồi sinh ở chỗ xuất phát của mình. Vừa hồi sinh được miễn sát thương 1,5 giây, trong lúc đó không bị dẫm lấy điểm.
- **Người dẫn điểm** đội vương miện và to hơn 25%, nên dễ bị dẫm hơn. Hoà điểm thì không ai có vương miện.

### Chống câu giờ

- Sau **30 giây** mà không ai ghi điểm, gai bắt đầu mọc từ hai bên mặt đất, cứ **2 giây** thêm một ô gai mỗi bên.
- Khi sàn đã kín gai và chờ thêm **4 giây** thì **SUDDEN DEATH**: một hàng gai kín bề ngang dâng từ đáy lên, tốc độ 35 pixel mỗi giây. Ai bị chạm là chết.
- Có người ghi điểm thì gai và hàng gai biến mất, đếm giờ lại từ đầu.

### Sự kiện ngẫu nhiên

Trận bắt đầu được 10 giây thì sự kiện đầu tiên bốc thăm, sau đó **cứ 15 giây một lần**. Trước mỗi sự kiện có màn quay roulette 2 giây giữa màn hình. Không lặp lại sự kiện vừa rồi.

| Sự kiện | Tác dụng | Thời gian |
|---|---|---|
| LOW GRAVITY | Trọng lực còn 40%: nhảy cao hơn, rơi chậm | 10 giây |
| SUPER BOUNCE | Bóng nảy gần như không mất lực | 10 giây |
| ICE FLOOR | Mặt đất như băng, bóng trượt rất lâu | 10 giây |
| REVERSED KEYS | Phím trái / phải của cả hai người bị đảo | 8 giây |
| SWAP! | Hai người đổi chỗ ngay lập tức | Tức thì |
| HOT POTATO | Quả bom trên đầu người cầm. Chạm đối thủ thì chuyền bom (chờ 1 giây mới chuyền tiếp được). Hết ngòi thì nổ, người cầm chết | Ngòi 8 giây |

Hết sự kiện thì mọi thứ được trả lại như cũ.

### Vật phẩm (hộp "?")

Hộp đầu tiên hiện 3 giây sau khi trận bắt đầu, sau đó **cứ 6 giây một hộp**, tối đa 2 hộp trên sân. Hộp không hiện gần người chơi hoặc gần hộp khác, và không nằm trên gai hay vực.
Chạm hộp lúc tay trống để nhặt. Mỗi người chỉ cầm một món, chết là mất. Dùng bằng phím S / ↓.

| Vật phẩm | Tác dụng |
|---|---|
| GUN | 3 phát. Mỗi phát hất đối thủ rất mạnh, không gây sát thương, nhưng đủ để đẩy họ xuống vực |
| BANANA | Đối thủ bị đảo trái / phải trong 3 giây |
| SWAP | Hai người đổi chỗ và vận tốc ngay |
| SPRING | Thả bẫy lò xo dưới chân. Sau 0,5 giây bẫy lên cò, ai chạm trước (kể cả chủ) bị bắn lên cao. Bẫy tự mất sau 12 giây |

### Câu châm chọc

Mỗi lần có điểm, giữa màn hình hiện một câu bốc ngẫu nhiên theo cách ghi điểm (dẫm, rơi, gai, bom...).
Muốn thêm câu: mở `scripts/brawl_data.gd`, chép một dòng vào đúng nhóm trong `TAUNTS`. `{s}` là người ghi điểm, `{v}` là người bị ghi điểm. Chỉ dùng chữ ASCII và câu ngắn.

### Đấu với máy

Bấm **BRAWL VS BOT** ở menu. Máy điều khiển người chơi 2 đúng bằng các phím của người chơi 2 (chỉ bấm phím, không dịch chuyển bóng).
Độ giỏi chỉnh ở `skill` trong `scripts/brawl_bot.gd` (từ 0 đến 1, mặc định 0,6): 0 thì chậm và vụng, 1 thì nhanh và chuẩn.

### Chỉnh ở đâu

| Chỉnh gì | Ở đâu |
|---|---|
| Điểm thắng (`WIN_SCORE`), thời gian hồi sinh (`respawn_delay`), miễn sát thương (`RESPAWN_INVULN`), vương miện (`LEADER_SCALE`) | `scripts/brawl.gd` |
| Câu chờ chống câu giờ (`stall_timeout`, `stall_step`) và SUDDEN DEATH (`sudden_death_delay`, `sudden_death_speed`) | `scripts/brawl.gd` |
| Khoảng cách và thời điểm sự kiện (`interval`, `first_delay`, `roulette_seconds`), thời gian từng sự kiện (`low_gravity_seconds`, `reversed_keys_seconds`, `hot_potato_seconds`...) | `scripts/brawl_events.gd` |
| Hộp vật phẩm (`spawn_interval`, `first_delay`, `max_boxes`), súng (`gun_knockback`), chuối (`banana_seconds`), bẫy lò xo (`spring_arm_seconds`, `spring_life_seconds`, `spring_launch`) | `scripts/brawl_items.gd` |
| Câu châm chọc (`TAUNTS`), đấu trường (`ARENAS`) | `scripts/brawl_data.gd` |
| Độ giỏi của máy (`skill`) | `scripts/brawl_bot.gd` |

### Thêm đấu trường mới

Mở `scripts/brawl_data.gd`, chép một khối `{"name": ..., "map": r"""..."""}` vào `ARENAS`, rồi sửa bản đồ. Quy tắc:

- Đúng **40 cột x 22 hàng** (một màn hình, mỗi ô 32 pixel). Cột đầu và cuối là tường `#`, hai hàng cuối là đất.
- `O` là chỗ xuất phát của người chơi 1, `P` là của người chơi 2. Vực là chỗ để trống ở hai hàng cuối.
- Nên **đối xứng qua giữa** để hai bên công bằng: cột `c` giống cột `39 - c`, `O` đối xứng với `P`.
- Các ký tự khác giống `scripts/level_data.gd` (`^` gai, `v` gai treo, `T` lò xo...).

### Kiểm tra

- `tests/brawl_soak.tscn`: hai bot đấu nhau trọn trận, in kết quả và dòng `ANOMALY` nếu có lỗi lạ. Chạy:
  `godot --headless --fixed-fps 60 --path . res://tests/brawl_soak.tscn`
- `tests/brawl_preview.tscn` (chạy có cửa sổ): chụp ảnh các đấu trường, gai, sự kiện, vật phẩm và vương miện.

## Vật phẩm, súng, boss

| Thứ | Ký tự | Tác dụng |
|---|---|---|
| Trái tim | `+` | +1 mạng (tối đa 3) |
| Khiên | `h` | Đỡ 1 đòn, có vòng sáng quanh nhân vật; vỡ khiên thì được miễn sát thương 1,2 giây |
| Jump boost | `j` | Mũi tên xanh: 10 giây nhảy mạnh hơn 25% (cao gấp khoảng 1,5 lần). Dưới chân hiện mũi tên, HUD có thanh đếm ngược. Chỉnh `Boost Duration`, `Boost Power` ở `scenes/ball.tscn` |
| Súng | `g` | +15 đạn; mọc lại sau 8 giây (đấu boss không bao giờ hết đạn) |
| Boss | `M` | GLOOMFANG: quả cầu quái vật **chỉ lăn trên mặt đất** (đặt `M` ngay trên mặt đất). Lăn qua lại, hiện **dấu ! đỏ** và rung lắc rồi **lao** về phía bạn, đâm tường thì **choáng** (sao vàng quay). Còn nửa máu thì đỏ lên, lăn và lao nhanh hơn. 12 máu. Cách đánh: **bắn ngang** (F / J) hoặc **nhảy lên đầu** (mỗi lần trừ 1 máu); đụng ngang thân thì bị thương |
| Cổng boss | `G` | Chặn đường, mở khi hạ boss |
| Dốc | `/` `\` `1` `2` `3` `4` | Dốc đứng lên/xuống; dốc thoải lên (1 rồi 2) và xuống (3 rồi 4). Ghép thành đồi, thung lũng |

Số chỉnh ở Inspector: boss (`scenes/objects/boss.tscn`: `Max Hp`, tốc độ lăn / lao, `Charge Every`, `Warn Time`, `Dizzy Time`, `Roam` vùng lăn), súng (`scenes/ball.tscn`:
`Shoot Cooldown`, `Max Ammo`, `Invuln After Hit`), số đạn mỗi lần nhặt (`Gun Ammo` trong `pickup.tscn`).

**Hướng dẫn trong game:** menu có nút **HOW TO PLAY** (nội dung sửa ở `HOW_TO_PLAY` trong `scripts/ui/menu.gd`); nhặt súng thì hiện "Press F or J to shoot"; ô đạn luôn ghi phím bắn; boss xuất hiện thì hiện cách đánh, dưới thanh máu boss có dòng nhắc.

**Hình của nhóm:** trái tim, khiên, jump boost dùng ảnh 16 x 16 trong `assets/items/` (`heart.png`, `shield.png`, `jump_boost.png`; nền đã chuyển trong suốt), vẽ phóng gấp 2. Ghi đè file là đổi hình, ở cả ngoài màn lẫn trên HUD.

**Hình pixel:** các hình còn lại (boss, đạn, tim, khiên, súng, thanh máu) vẽ bằng code từ các mảng chữ trong
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
  - Cờ lưu tính cả khi nhảy vòng qua phía trên cờ (vùng chạm cao 10 ô, chỉnh ở `CHECKPOINT_HEIGHT` trong `scripts/objects/pickups.gd`).
  - Vừa hồi sinh được miễn sát thương 1,5 giây. Hết thời gian đó mà vẫn đứng trên gai hoặc chạm quái thì bị thương.
  - Quái quay đầu khi gặp gai, không đi xuyên qua bãi gai.
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

## Logo và font

- **Logo tiêu đề:** `assets/ui/logo.png` (ảnh của nhóm, 585 x 214, hiện ở menu với 70% kích thước, phập phồng nhẹ).
  Thay file là đổi logo; đổi cỡ ở `LOGO_SIZE` trong `scripts/ui/menu.gd`.
- **Font chính:** Peaberry (`assets/fonts/PeaberryBase.ttf`), font pixel của Emily Huo, giấy phép **SIL Open Font License**
  (`assets/fonts/Peaberry-OFL.txt`): dùng miễn phí cả thương mại, không bắt buộc ghi tên. Có đủ dấu tiếng Việt.
  - Font sắc nét nhất ở cỡ **16, 32, 48**: dùng các hằng `FONT_SMALL`, `FONT_MEDIUM`, `FONT_LARGE` trong `scripts/ui/ui_theme.gd`
    thay vì gõ số khác.
  - Ký tự font không có tự lấy từ font hệ thống (chỉ trên máy tính; trên web không có font hệ thống, nên ngôi sao ở menu là icon pixel).
  - Đổi font: thay `FONT_PATH` trong `ui_theme.gd`.

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
| `scripts/brawl.gd` | Chế độ Bounce Brawl (2 người): đấu trường, điểm, hồi sinh, gai chống câu giờ, SUDDEN DEATH, vương miện |
| `scripts/brawl_events.gd` | Sự kiện ngẫu nhiên của Brawl (LOW GRAVITY, HOT POTATO...) và màn quay roulette |
| `scripts/brawl_items.gd` | Vật phẩm troll của Brawl: hộp, súng, chuối, đổi chỗ, bẫy lò xo |
| `scripts/brawl_bot.gd` | Máy chơi Brawl (BRAWL VS BOT) |
| `scripts/brawl_data.gd` | Đấu trường và câu châm chọc của Brawl |
| `scripts/ui/brawl_hud.gd` | Giao diện Brawl: điểm, dòng thông báo, bảng thắng |
| `scripts/play.gd` | Camera, mạng, sao, hồi sinh, qua màn |
| `scripts/objects/` | Quái, thùng, gai, nút, cửa, bệ, bập bênh, sao/cờ/đích/lò xo |
| `scripts/ui/` | Menu, HUD, giao diện |
| `scripts/autoload/game.gd` | Phím, chuyển cảnh, nhớ sao |

## Kiểm tra tự động

```
godot --headless --fixed-fps 60 --path . res://tests/smoke.tscn
```

Chạy hơn 380 kiểm tra (cơ chế, quy tắc đoạn vô tận, chế độ vô tận, hồi sinh, Bounce Brawl). `tests/soak.tscn` cho một bot chơi ngẫu nhiên chế độ vô tận và cả 3 màn để dò lỗi lúc chạy (dòng `ANOMALY` là chỗ cần xem). `tests/segments_preview.tscn` (chạy có cửa sổ) chụp toàn cảnh từng đoạn. `tests/measure.tscn` đo lại tầm nhảy sau khi chỉnh số; `tests/ball_preview.tscn` (chạy có cửa sổ) chụp ảnh phóng to nhân vật.

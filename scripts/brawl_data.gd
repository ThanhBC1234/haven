class_name BrawlData
## Các đấu trường của chế độ 2 người (Bounce Brawl). Mỗi đấu trường vừa đúng một màn hình 1280 x 720:
## 40 cột x 22 hàng (mỗi ô 32 pixel), camera cố định, không cuộn.
## Ký tự giống scripts/level_data.gd (# đất, ^ gai, v gai treo, T lò xo, O chỗ xuất phát của người chơi 1...),
## thêm một ký tự riêng của chế độ này:
##
##   P  chỗ xuất phát của người chơi 2 (Level bỏ qua ký tự này, brawl.gd tự đọc)
##
## Quy tắc khi vẽ đấu trường mới (có bài test kiểm tra):
##   - đúng 40 cột x 22 hàng, cột 0 và cột 39 là tường (#) từ trên xuống dưới
##   - hai hàng cuối là đất; vực (hố rơi) là chỗ hai hàng cuối để trống (.)
##   - đối xứng gương qua giữa (cột c giống cột 39 - c), O đối xứng với P, cho công bằng
##   - hàng thứ 3 từ dưới (hàng sát mặt đất) là nơi gai chống câu giờ mọc ra, nên giữ nó đúng là "mặt đất"
## Thêm đấu trường: chép một khối {"name": ..., "map": r"""..."""} vào ARENAS. Chế độ chơi tự bốc ngẫu nhiên.

const COLS := 40                       # số cột của đấu trường
const ROWS := 22                       # số hàng của đấu trường
const PLAYER2_CHAR := "P"              # ký tự chỗ xuất phát của người chơi 2

## Câu châm chọc hiện giữa trên màn hình mỗi khi có điểm, bốc ngẫu nhiên theo nguyên nhân (Brawl._point_text).
## {s} = tên người ghi điểm (P1 / P2), {v} = tên nạn nhân. Chỉ chữ ASCII, ngắn gọn (có bài test đo bề rộng ở cỡ chữ lớn).
## Muốn thêm câu: chép một dòng vào đúng nhóm. "default" dùng cho nguyên nhân lạ (sự kiện, vật phẩm...).
const TAUNTS := {
	"stomp": [
		"{s} STOMPS {v}!", "{s} FLATTENED {v}!", "{v} IS NOW A PANCAKE!", "{s} SAT ON {v}'S HEAD!",
		"{v} GOT SQUASHED!", "NICE HEAD, {v}! SO BOUNCY!", "{s} USED {v} AS A TRAMPOLINE!", "{v} GOT PRESSED FLAT!",
		"STOMP! {v} IS PANCAKE!",
	],
	"pit": [
		"{v} FELL IN!", "{v} FORGOT HOW TO JUMP!", "{v} FOUND THE BOTTOM!", "BYE BYE, {v}!",
		"{v} SAYS HI TO THE VOID!", "THE PIT LOVES {v}!", "MIND THE GAP, {v}!", "{s} WAVES BYE TO {v}!",
		"{v} TOOK THE FAST WAY DOWN!",
	],
	"spikes": [
		"{v} GOT SPIKED!", "OUCH! {v} MEETS THE SPIKES!", "{v} DID NOT SEE THE SPIKES!", "{v} IS A PINCUSHION NOW!",
		"{v} POPPED LIKE A BALLOON!", "{s} THANKS THE SPIKES!", "SPIKES 1, {v} 0!", "{v} SAT ON A PORCUPINE!",
	],
	"bomb": [
		"{v} WENT BOOM!", "{v} GOT TOO HOT TO HANDLE!", "{v} IS TOAST!", "HOT POTATO! {v} IS WELL DONE!",
		"{v} BLEW IT!", "{s} SAYS: BOOM, {v}!", "{v} EXPLODED WITH JOY!", "BOOM! SEE YA, {v}!",
	],
	"default": [
		"{s} SCORES!", "{s} TAKES A POINT!", "POINT FOR {s}!", "{s} IS ON FIRE!",
		"{s} MAKES IT LOOK EASY!", "{v} MESSED UP BIG TIME!", "NICE ONE, {s}!", "{v} TRIPPED OVER NOTHING!",
	],
}

const ARENAS := [
	# vực to ở giữa, bệ cao ở giữa có gai treo bên dưới, hai lò xo bắn lên bệ
	{"name": "Center Pit", "map": r"""
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#...............########...............#
#.................vvvv.................#
#......................................#
#..........####..........####..........#
#......................................#
#.....#####..................#####.....#
#......................................#
#..O........^^.T........T.^^........P..#
##################....##################
##################....##################
"""},
	# hai vực sát hai bên, gò đất giữa có gai, lò xo bắn lên bệ cao
	{"name": "Twin Pits", "map": r"""
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#..............##########..............#
#......................................#
#......................................#
#...#####......................#####...#
#......................................#
#......................................#
#..........####..........####..........#
#......................................#
#......................................#
#..................^^..................#
#..O.....T......########......T.....P..#
##########...##############...##########
##########...##############...##########
"""},
]

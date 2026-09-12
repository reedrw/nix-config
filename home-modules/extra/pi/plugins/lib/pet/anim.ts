// Pet animation state machine — ported from pi-dsh-pet's assets/config.jsonc
// and pi/assets/pet.js (MIT, https://github.com/SOMWHY/pi-dsh-pet).
//
// States: "idle" (weighted random chain), "thinking" / "coding" (pi agent
// state overrides), plus one-shot user-interaction animations (click, drag)
// that play out before the current state resumes. Walking/move animations are
// omitted — they need the pet to travel across the screen, which the terminal
// overlay can do later via offset animation, but v1 stays put.

export type PetState = "idle" | "thinking" | "coding";

/** Weighted idle-chain entry: either a category of animations or a fixed one. */
interface ChainEntry {
	weight: number;
	anims: string[];
}

// Upstream weights: idle 10, turn 5, move 5 (moves skipped → renormalized by
// the picker), categories 小动作 20 / 玩耍 20 / 吃什么 16 / 时节 14 / 文字 10.
const CHAIN: ChainEntry[] = [
	{ weight: 10, anims: ["待机呼吸休闲"] },
	{ weight: 5, anims: ["东张西望"] },
	{
		weight: 20,
		anims: [
			"悠闲哼歌", "超大伸懒腰", "原地敲击桌面互动", "原地重力下蹲压缩",
			"哈欠连天", "原地小憩沉眠", "女仆屈膝礼仪", "被吓一跳",
			"小幅度原地360度旋转展示", "偷吃零食被抓住", "用鲸鱼尾巴拍打地面",
			"打瞌睡被惊醒", "照镜子", "整体换装试色", "轻快记录", "写代码", "摇扇纳凉",
			"晨间刷牙",
		],
	},
	{
		weight: 20,
		anims: [
			"原地专心玩魔方", "原地蹲下玩玩具汽车", "鲸鱼吐泡泡特效",
			"原地跳跃抓碎头顶物品", "玩游戏气急败坏", "玩水枪", "小提琴演奏",
			"蓝鲸现世", "优雅女仆舞", "轻快摇摆舞", "可爱宅舞", "吹气球", "动物环绕",
			"放风筝", "拆礼物", "变鸽子", "扑克魔术", "抽陀螺", "吹笛子",
			"蝴蝶蜜蜂环绕头顶开花", "撸猫", "凭空生花", "骑木马", "三球抛接",
			"踢毽子", "下五子棋", "荡秋千",
		],
	},
	{
		weight: 16,
		anims: [
			"吃白饭", "大口吃零食", "吃Token", "吃早餐", "吃午餐", "吃晚餐",
			"吃冰淇淋融化", "吃大闸蟹", "吃糖葫芦", "吃长寿面", "吃西瓜", "涮火锅",
		],
	},
	{
		weight: 14,
		anims: [
			"被落叶淹没", "中秋赏月吃月饼", "堆雪人", "放烟花", "吃粽子", "吃年糕",
			"吃青团", "吃腊八粥", "吃重阳糕", "收红包", "写福字", "穿针乞巧",
			"舞狮头", "讨糖南瓜灯", "插茱萸赏菊", "放河灯", "萌化小幽灵",
			"装点圣诞树", "放孔明灯", "吃汤圆", "吃饺子",
		],
	},
	{ weight: 10, anims: ["是啊，吃什么", "深度思考碎碎念"] },
];

const CLICK_ANIMS = [
	"点击回应-开心跃动",
	"点击回应-害羞惊讶",
	"点击回应-傲娇生气",
	"点击回应-挠痒咯咯笑",
	"点击回应-元气挥手",
];

const DRAG_ANIM = "被鼠标拖拽悬空反馈";
const THINKING_ANIM = "深度思考碎碎念";
const CODING_ANIM = "写代码";

/** Tools whose execution shows the coding animation (upstream TOOL_ANIM_MAP). */
export const CODING_TOOLS = new Set([
	"bash",
	"read",
	"edit",
	"write",
	"grep",
	"find",
	"execute",
	"nix-comma",
]);

function pick(list: string[], available: Set<string>, avoid?: string): string | null {
	const pool = list.filter((a) => available.has(a) && a !== avoid);
	if (pool.length === 0) return null;
	return pool[Math.floor(Math.random() * pool.length)]!;
}

/**
 * Pick the next idle-chain animation. `available` is the set of animation
 * names present in the asset manifest; entries with no available animations
 * are skipped (weights of the rest renormalize implicitly).
 */
export function pickIdleChain(available: Set<string>, avoid?: string): string | null {
	const entries = CHAIN
		.map((e) => ({ weight: e.weight, anim: pick(e.anims, available, avoid) }))
		.filter((e): e is { weight: number; anim: string } => e.anim !== null);
	const total = entries.reduce((sum, e) => sum + e.weight, 0);
	if (total === 0) return null;
	let roll = Math.random() * total;
	for (const e of entries) {
		roll -= e.weight;
		if (roll <= 0) return e.anim;
	}
	return entries[entries.length - 1]!.anim;
}

export function pickClick(available: Set<string>): string | null {
	return pick(CLICK_ANIMS, available);
}

export const dragAnim = DRAG_ANIM;
export const thinkingAnim = THINKING_ANIM;
export const codingAnim = CODING_ANIM;

/**
 * Should a state change interrupt the currently playing animation? User
 * interaction animations (click/drag responses) always play out first;
 * anything else is preempted by thinking/coding state changes.
 */
export function isInteractionAnim(name: string): boolean {
	return CLICK_ANIMS.includes(name) || name === DRAG_ANIM;
}

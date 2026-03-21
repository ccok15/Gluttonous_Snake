# ARCHITECTURE

## 1. 项目概览

这是一个基于 Godot 4.6.1 的贪吃蛇 x 肉鸽原型项目。
首版目标是先验证核心循环：

- 吃真豆
- 累积总分与经验
- 达到升级阈值后弹出三选一
- 在阶段时间内达到累计分数目标
- 失败后快速重开

## 2. 目录地图与职责

- `scenes/core/`
  - `Boot.tscn`：主入口，加载默认配置并初始化全局状态。
  - `MainMenu.tscn`：主菜单。
- `scenes/game/`
  - `GameRun.tscn`：主玩法场景。
- `scenes/ui/`
  - `GameHud.tscn`：右侧信息面板。
  - `DebugHud.tscn`：调试面板。
  - `UpgradeOverlay.tscn`：升级三选一弹窗。
- `scripts/core/`
  - 配置资源、存档资源、Autoload、Boot/MainMenu 逻辑。
- `scripts/game/`
  - 主玩法循环、棋盘绘制层、蛇、豆子、预览与障碍预留层。
- `scripts/ui/`
  - HUD、调试 HUD、升级弹窗逻辑。
- `data/config/`
  - 默认运行配置、阶段配置、升级定义资源。
- `data/obstacles/`
  - 障碍布局资源。
- `docs/planning/`
  - 非代码资料区，统一存放策划、数值与表格文件。
  - `design/`：玩法策划、系统设定、流程草案。
  - `balance/`：数值规划、成长曲线、调参记录。
  - `spreadsheets/`：Excel、CSV、TSV 等表格资料。

## 3. 核心玩法流程

1. `Boot.tscn` 读取默认 `RunConfig` 并初始化 `GameApp`。
2. 切到 `MainMenu.tscn`。
3. 玩家进入 `GameRun.tscn` 后开始一局。
4. 蛇在当前阶段棋盘上移动，首阶段默认是 `20x20`，后续阶段会逐步扩大地图并增加豆子数量。
5. 真豆带来分数和经验。
6. 经验到阈值后暂停游戏，弹出升级三选一。
7. 玩家选择后恢复游戏，并获得 `0.5` 秒保护期。
8. 达到阶段目标分数后进入下一阶段，剩余时间不会重置，而是在当前基础上追加 `60` 秒，并切换到新阶段的棋盘尺寸与豆子数量。
9. 超时未达标或发生致命碰撞则结束本局。

## 4. 关键场景职责

- `Boot`
  - 加载默认运行配置。
  - 确保存档骨架存在。
- `MainMenu`
  - 开始新局。
  - 预留继续游戏入口。
- `GameRun`
  - 管理蛇、豆子、升级、阶段与失败判定。
  - 当前升级池为：`轻量成长`、`微型磁吸`、`移动加速`、`突进`、`暴击豆下限`、`暴击豆上限`、`暴击豆留存`、`穿墙术`。

## 5. 关键脚本职责

- `scripts/core/run_config.gd`
  - 全局可调运行参数、初始蛇参数、暴击豆刷新参数、暂停键与默认资源引用。
- `scripts/core/stage_config.gd`
  - 单阶段目标、时间、地图尺寸、豆子数量和预留难度配置。
- `scripts/core/upgrade_def.gd`
  - 单个升级定义、文案模板与等级数值。
- `scripts/core/save_profile.gd`
  - 局外解锁与基础设置骨架。
- `scripts/core/game_app.gd`
  - 持有 `RunConfig`、`SaveProfile`、调试开关。
- `scripts/game/game_run.gd`
  - 主循环、状态机、分数、经验、升级、阶段推进、暂停、阶段加时，以及 `突进`、`暴击豆下限 / 上限 / 留存`、`穿墙术` 的运行逻辑。
- `scripts/game/bean_tile_map.gd`
  - 普通豆与暴击豆的绘制；暴击豆使用独立颜色、环形高亮和闪烁可见性。
- `scripts/game/score_popup_layer.gd`
  - 在豆子位置生成 `+分数` 飘字，不参与玩法判定。

## 6. 全局单例 / Autoload

- `GameApp`
  - 保存当前 `RunConfig`
  - 读取与保存 `SaveProfile`
  - 持有调试 HUD 显示状态
  - 持有当前语言与语言资源表
  - 提供统一 `tr_key` 文案访问入口

## 7. 数据流与存档流

- 运行配置来自 `res://data/config/run/default_run_config.tres`
- 阶段与升级定义来自 `res://data/config/stages/` 与 `res://data/config/upgrades/`
- 当前语言资源来自 `res://data/config/localization/`
- 存档保存到 `user://save_profile.tres`
- 策划与数值资料统一放在 `res://docs/planning/`
- 当前整局节奏总控表为 `res://docs/planning/spreadsheets/run_balance_config.xlsx`

## 8. 调试系统与发布开关

- `F1` 切换调试 HUD。
- 正式 HUD 与调试 HUD 独立。
- 调试 HUD 只读展示状态，不驱动玩法逻辑。
- 文案显示统一经过 `GameApp.tr_key()`，后续切换语言时不需要重写 UI 逻辑。
- 当前 HUD 额外显示：突进冷却、普通豆得分、暴击豆分值区间与刷新状态、穿墙剩余次数。
- 当前暂停入口为 `P`，暂停层不会改动玩法数据，只切断本局推进。

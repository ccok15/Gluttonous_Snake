# INTERFACES

## GameApp

- 模块名：`GameApp`
- 对外信号/事件：
  - `locale_changed(locale_code)`
- 可调用公开方法：
  - `set_run_config(config)`
  - `load_or_create_save_profile()`
  - `save_profile_to_disk()`
  - `register_language_packs(packs, default_locale)`
  - `set_locale(locale_code)`
  - `tr_key(key, replacements, fallback)`
  - `toggle_debug_hud()`
  - `mark_score(score)`
- 输入预期：传入有效的 `RunConfig` 或整数分数
- 输出效果：更新全局配置、保存存档、切换调试 HUD、提供统一本地化文本
- 依赖项：`RunConfig`、`SaveProfile`

## GameRun

- 模块名：`GameRun`
- 对外信号/事件：
  - `bean_eaten`
  - `score_changed`
  - `level_up`
  - `upgrade_applied`
  - `stage_started`
  - `stage_cleared`
  - `run_failed(reason)`
- 可调用公开方法：
  - `start_new_run()`
- 输入预期：场景已挂好 HUD、Overlay 与配置资源
- 输出效果：开始一局、按阶段切换棋盘尺寸与豆子数量、处理暂停、阶段加时、`突进`、`暴击豆下限/上限/留存`、`穿墙术` 效果，并发出升级与失败事件
- 依赖项：`RunConfig`、`StageConfig`、`UpgradeDef`、`GameHud`、`DebugHud`、`UpgradeOverlay`

## GameHud

- 模块名：`GameHud`
- 对外信号/事件：
  - `restart_requested`
- 可调用公开方法：
  - `update_view(data)`
- 输入预期：传入包含阶段、分数、时间、速度、暴击豆状态、提示文本等字段的字典
- 输出效果：刷新右侧 HUD，并在本局失败时显示“重新开始”按钮
- 依赖项：`GameApp`

## ScorePopupLayer

- 模块名：`ScorePopupLayer`
- 对外信号/事件：无
- 可调用公开方法：
  - `spawn_popup(cell, cell_size, score_gain, is_critical)`
  - `clear_popups()`
- 输入预期：传入棋盘坐标、格子尺寸、分数与是否为暴击豆
- 输出效果：在棋盘指定位置生成并自动回收 `+分数` 飘字
- 依赖项：无

## UpgradeOverlay

- 模块名：`UpgradeOverlay`
- 对外信号/事件：
  - `option_chosen(definition)`
- 可调用公开方法：
  - `show_choices(choices, current_levels)`
  - `hide_overlay()`
- 输入预期：传入 1-3 个升级定义
- 输出效果：显示三选一面板并在点击时发出选择结果
- 依赖项：`UpgradeDef`

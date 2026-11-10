-- Runtime settings only. Pack-specific assets live in declarative pack data.
return {
    solo_click_window = .35, mod_id = "SceneZOI_93C44199", section = "scenezoi_runtime", data_table = "Text", data_prefix = "SceneZOI_Declaration_",
    picker_cap = 3, poll_interval = 0.2, prepare_timeout = 8.0, lease_timeout = 6.0,
    max_npc_sessions = 15, standing_spacing_cm = 200, background_max_start_distance_cm = 1500,
    background_default_seconds = 600, background_max_seconds = 7200,
    plan_max_goals = 16, plan_max_completions = 100, plan_min_multiplier = 0.1, plan_max_multiplier = 5,
    plan_max_seconds = 7200, plan_max_playback_seconds = 7200, plan_min_dwell_seconds = 4,
    plan_no_progress_seconds = 90, plan_wait_seconds = 300, plan_route_limit = 256,
    plan_max_stages = 16, plan_ramp_finish = 1.25, plan_min_speed = 0.5, plan_max_speed = 1.5,
    heartbeat_interval = 1.0, slot = "DefaultSlot", max_duration_difference = 0.0001,
    playback_speeds = {0.50, 1.00, 1.50, 2.00},
    build = "20261109-concurrent-sessions-1",
}

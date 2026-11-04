-- Runtime settings only. Pack-specific assets live in declarative pack data.
return {
    mod_id = "SceneZOI_93C44199", section = "scenezoi_runtime", data_table = "Text", data_prefix = "SceneZOI_Declaration_",
    picker_cap = 3, poll_interval = 0.2, prepare_timeout = 8.0, lease_timeout = 6.0,
    heartbeat_interval = 1.0, slot = "DefaultSlot", max_duration_difference = 0.0001,
    playback_speeds = {0.50, 1.00, 1.50, 2.00},
    build = "20261102-voice-1",
}

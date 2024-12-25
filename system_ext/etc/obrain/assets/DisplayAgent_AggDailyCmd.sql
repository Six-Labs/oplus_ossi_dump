-- val_start_ts,      --obrain_start_ts
-- val_end_ts,        --obrain_end_ts
-- val_wall_start_ts  --wall_start_ts_round

insert into agg_display_app_daily
select
    {val_start_ts} as start_ts,
    {val_end_ts} as end_ts,
    {val_wall_start_ts} as timestamp,
    name,
    sum(duration) as duration,
    sum(energy) as energy,
    mode
from agg_display_app_hourly
where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
group by name, mode;

insert into agg_display_device_daily
select
    {val_start_ts} as start_ts,
    {val_end_ts} as end_ts,
    {val_wall_start_ts} as timestamp,
    sum(duration) as duration,
    sum(energy) as energy,
    sum(screen_off_duration) as screen_off_duration,
    sum(screen_off_energy) as screen_off_energy
from (
    select
        {val_start_ts} as start_ts,
        {val_end_ts} as end_ts,
        {val_wall_start_ts} as timestamp,
        case when (mode <> 1 and mode <> 2) then duration else 0 end as duration,
        case when (mode <> 1 and mode <> 2) then energy else 0 end as energy,
        case when (mode = 1 or mode = 2) then duration else 0 end as screen_off_duration,
        case when (mode = 1 or mode = 2) then energy else 0 end as screen_off_energy
    from agg_display_app_hourly
    where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
);

insert into agg_screen_brightness_fps_app_daily
select
    {val_start_ts} as start_ts,
    {val_end_ts} as end_ts,
    {val_wall_start_ts} as timestamp,
    screen_mode, power_mode, name, (brightness / 100) * 100 as brightness, fps, render_fps, sum(total_du) as total_du
    from agg_screen_brightness_fps_app_hourly
where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
group by screen_mode, power_mode, name, brightness, fps, render_fps;

--by_app  upload dcs-------------------------------------------------------------------------
select upload_dcs('{upload_dcs_key}', '{log_tag_app}', '{config_id_app}', {version}, '{type}', {agent_type},
                  '{id}', '{start_wall_time}', '{end_wall_time}', '{meta_data}', by_app)
from (
    select json_insert(json_set('{{}}', '$.column_key', json(column_key)), '$.row_value', json(row_value)) as 'by_app'
    from (
        select
            json_set('{{}}', '$', json_array('timestamp', 'name', 'duration', 'energy', 'mode')) as column_key,
            json_set('{{}}', '$', json_group_array(json_array(timestamp, obfuscate(name), duration, energy, mode))) as row_value
        from agg_display_app_daily
        where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
    )
);

--by_device  upload dcs-------------------------------------------------------------------------
select upload_dcs('{upload_dcs_key}', '{log_tag_device}', '{config_id_device}', {version}, '{type}', {agent_type},
                  '{id}', '{start_wall_time}', '{end_wall_time}', '{meta_data}', by_device)
from (
    select json_insert(json_set('{{}}', '$.column_key', json(column_key)), '$.row_value', json(row_value)) as 'by_device'
    from (
        select
            json_set('{{}}', '$', json_array('timestamp', 'duration', 'energy', 'screen_off_duration', 'screen_off_energy')) as column_key,
            json_set('{{}}', '$', json_group_array(json_array(timestamp, duration, energy, screen_off_duration, screen_off_energy))) as row_value
        from agg_display_device_daily
        where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
    )
);

--by_brightness_fps  upload dcs-------------------------------------------------------------------------
select upload_dcs('{upload_dcs_key}', '{log_tag_app}', '{config_id_brightness_fps}', {version}, '{type}', {agent_type},
                  '{id}', '{start_wall_time}', '{end_wall_time}', '{meta_data}', by_brightness_fps)
from (
    select json_insert(json_set('{{}}', '$.column_key', json(column_key)), '$.row_value', json(row_value)) as 'by_brightness_fps'
    from (
        select
            json_set('{{}}', '$', json_array('timestamp', 'total_du', 'screen_mode', 'power_mode', 'name', 'brightness', 'fps', 'render_fps')) as column_key,
            json_set('{{}}', '$', json_group_array(json_array(timestamp, total_du, screen_mode, power_mode, obfuscate(name), brightness, fps, render_fps))) as row_value
        from agg_screen_brightness_fps_app_daily
        where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
    )
);

--by_app
--|start_ts     |end_ts       |timestamp    |name                        |duration|energy   |mode|
--|1676527498885|1676616381000|1676528031002|com.android.launcher@13.1.01|872473  |49321048 |0   |

--by_device
--|start_ts     |end_ts       |timestamp    |duration|energy  |screen_off_duration|screen_off_energy|
--|1676527498885|1676616381000|1676528031002|1659183 |86621515|296837             |0                |


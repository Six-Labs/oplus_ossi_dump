-- val_start_ts,      --obrain_start_ts
-- val_end_ts,        --obrain_end_ts
-- val_wall_start_ts  --wall_start_ts_round

insert into agg_battery_device_daily
select
    {val_start_ts} as 'start_ts',
    {val_end_ts} as 'end_ts',
    {val_wall_start_ts} as 'timestamp',
    sum(discharge_screen_on_duration) as discharge_screen_on_duration,
    sum(discharge_screen_on_fuel_gauge) as discharge_screen_on_fuel_gauge,
    sum(discharge_screen_on_level) as discharge_screen_on_level,
    sum(discharge_screen_off_duration) as discharge_screen_off_duration,
    sum(discharge_screen_off_fuel_gauge) as discharge_screen_off_fuel_gauge,
    sum(discharge_screen_off_level) as discharge_screen_off_level,
    sum(charge_screen_on_duration) as charge_screen_on_duration,
    sum(charge_screen_on_fuel_gauge) as charge_screen_on_fuel_gauge,
    sum(charge_screen_on_level) as charge_screen_on_level,
    sum(charge_screen_off_duration) as charge_screen_off_duration,
    sum(charge_screen_off_fuel_gauge) as charge_screen_off_fuel_gauge,
    sum(charge_screen_off_level) as charge_screen_off_level
from agg_battery_device_hourly
where start_ts >= {val_start_ts} and end_ts <= {val_end_ts};

insert into agg_battery_app_daily
select
    {val_start_ts} as 'start_ts',
    {val_end_ts} as 'end_ts',
    {val_wall_start_ts} as 'timestamp',
    name,
    screen_mode,
    power_mode,
    sum(foreground_duration) as foreground_duration,
    sum(foreground_energy) as foreground_energy
from agg_battery_app_hourly
where (start_ts >= {val_start_ts} and end_ts <= {val_end_ts})
group by name, screen_mode, power_mode;

--by_device  upload dcs-------------------------------------------------------------------------
select upload_dcs('{upload_dcs_key}', '{log_tag_device}', '{config_id_device}', {version}, '{type}', {agent_type},
                  '{id}', '{start_wall_time}', '{end_wall_time}', '{meta_data}', by_device)
from (
    select json_insert(json_set('{{}}', '$.column_key', json(column_key)), '$.row_value', json(row_value)) as 'by_device'
    from (
        select
            json_set('{{}}', '$', json_array('timestamp',
                    'discharge_screen_on_duration', 'discharge_screen_on_fuel_gauge', 'discharge_screen_on_level',
                    'discharge_screen_off_duration', 'discharge_screen_off_fuel_gauge', 'discharge_screen_off_level',
                    'charge_screen_on_duration', 'charge_screen_on_fuel_gauge', 'charge_screen_on_level',
                    'charge_screen_off_duration', 'charge_screen_off_fuel_gauge', 'charge_screen_off_level')) as column_key,
            json_set('{{}}', '$', json_group_array(json_array(timestamp,
                    discharge_screen_on_duration, discharge_screen_on_fuel_gauge, discharge_screen_on_level,
                    discharge_screen_off_duration, discharge_screen_off_fuel_gauge, discharge_screen_off_level,
                    charge_screen_on_duration, charge_screen_on_fuel_gauge, charge_screen_on_level,
                    charge_screen_off_duration, charge_screen_off_fuel_gauge, charge_screen_off_level))) as row_value
        from agg_battery_device_daily
        where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
    )
);

--by_device
--|start_ts     |end_ts       |timestamp    |discharge_screen_on_duration|discharge_screen_on_fuel_gauge|discharge_screen_on_level|discharge_screen_off_duration|discharge_screen_off_fuel_gauge|discharge_screen_off_level|charge_screen_on_duration|charge_screen_on_fuel_gauge|charge_screen_on_level|charge_screen_off_duration|charge_screen_off_fuel_gauge|charge_screen_off_level|
--|1676359917975|1676359958037|1676358000000|1833549                     |86000000                      |4                        |139068863                    |445000000                      |10                        |943268                   |76000000                   |2|11386               |1000000                   |0                           |

--by_app  upload dcs-------------------------------------------------------------------------
select upload_dcs('{upload_dcs_key}', '{log_tag_app}', '{config_id_app}', {version}, '{type}', {agent_type},
                  '{id}', '{start_wall_time}', '{end_wall_time}', '{meta_data}', by_app)
from (
    select json_insert(json_set('{{}}', '$.column_key', json(column_key)), '$.row_value', json(row_value)) as 'by_app'
    from (
        select
            json_set('{{}}', '$', json_array('timestamp', 'name',
                    'screen_mode', 'charger_mode',
                    'foreground_duration', 'foreground_energy')) as column_key,
            json_set('{{}}', '$', json_group_array(json_array(timestamp, obfuscate(name),
                    screen_mode, power_mode,
                    foreground_duration, foreground_energy))) as row_value
        from agg_battery_app_daily
        where start_ts >= {val_start_ts} and end_ts <= {val_end_ts}
    )
);

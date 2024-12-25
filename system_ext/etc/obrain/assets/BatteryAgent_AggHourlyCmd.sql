-- val_start_ts,      --obrain_start_ts
-- val_end_ts,        --obrain_end_ts
-- val_wall_start_ts  --wall_start_ts_round

insert into agg_battery_device_hourly
select
    {val_start_ts} as 'start_ts',
    {val_end_ts} as 'end_ts',
    {val_wall_start_ts} as 'timestamp',
    sum(case when power_mode = 0 and screen_mode = 1 then time_delta else 0 end) as discharge_screen_on_duration,
    sum(case when power_mode = 0 and screen_mode = 1 then (-rm_delta) else 0 end) as discharge_screen_on_fuel_gauge,
    sum(case when power_mode = 0 and screen_mode = 1 then (-battery_level_delta) else 0 end) as discharge_screen_on_level,
    sum(case when power_mode = 0 and screen_mode = 0 then time_delta else 0 end) as discharge_screen_off_duration,
    sum(case when power_mode = 0 and screen_mode = 0 then (-rm_delta) else 0 end) as discharge_screen_off_fuel_gauge,
    sum(case when power_mode = 0 and screen_mode = 0 then (-battery_level_delta) else 0 end) as discharge_screen_off_level,
    sum(case when power_mode = 1 and screen_mode = 1 then time_delta else 0 end) as charge_screen_on_duration,
    sum(case when power_mode = 1 and screen_mode = 1 then whole_eg else 0 end) as charge_screen_on_fuel_gauge,
    sum(case when power_mode = 1 and screen_mode = 1 then battery_level_delta else 0 end) as charge_screen_on_level,
    sum(case when power_mode = 1 and screen_mode = 0 then time_delta else 0 end) as charge_screen_off_duration,
    sum(case when power_mode = 1 and screen_mode = 0 then whole_eg else 0 end) as charge_screen_off_fuel_gauge,
    sum(case when power_mode = 1 and screen_mode = 0 then battery_level_delta else 0 end) as charge_screen_off_level
from comp_batteryAgent_appPower_intv
where (start_ts >= {val_start_ts} and end_ts <= {val_end_ts});

insert into agg_battery_app_hourly
select
    {val_start_ts} as 'start_ts',
    {val_end_ts} as 'end_ts',
    {val_wall_start_ts} as 'timestamp',
    app as name,
    screen_mode as screen_mode,
    power_mode as power_mode,
    sum(time_delta) as foreground_duration,
    sum(case when power_mode = 1 then whole_eg else abs(rm_delta) end) as foreground_energy
from comp_batteryAgent_appPower_intv
where (start_ts >= {val_start_ts} and end_ts <= {val_end_ts})
and power_mode != -1
and screen_mode != -1
group by app, screen_mode, power_mode;

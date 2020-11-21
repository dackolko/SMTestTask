create or replace package utils_pkg is

  procedure add_street(p_name_street varchar2
                      ,p_first_x     number
                      ,p_first_y     number
                      ,p_second_x    number
                      ,p_second_y    number);
  procedure delete_street(p_name streets.name_street%type);
  procedure add_wifi_point(p_name   varchar2
                          ,p_radius number
                          ,p_x      number
                          ,p_y      number);
  procedure delete_point(p_id_point wifipoints.id_point%type);
  function dist_to_line(p_p  coordinate
                       ,p_p1 coordinate
                       ,p_p2 coordinate) return number;
  function dist_between_points(p_a coordinate
                              ,p_b coordinate) return number;
  function dist_between_points(p_x1 number
                              ,p_y1 number
                              ,p_x2 number
                              ,p_y2 number) return number;
  procedure dijkstra(p_a coordinate);
  function get_optimal_way(p_a coordinate
                          ,p_b coordinate) return sys_refcursor;
  function calc_cost(p_cost1 number
                    ,p_cost2 number
                    ,p_wifi  number := null) return number;
end utils_pkg;
/
create or replace package body utils_pkg is
  -- Функция стоимости
  function calc_cost(p_cost1 number
                    ,p_cost2 number
                    ,p_wifi  number := null) return number is
    l_koef number;
  begin
    l_koef := case p_wifi
                when 0 then
                 1000
                when 1 then
                 1
                else
                 1
              end;
    return(p_cost1 + p_cost2) * l_koef;
  end;
  -- Расчет оптимального пути
  function get_optimal_way(p_a coordinate
                          ,p_b coordinate) return sys_refcursor is
    l_ret_val sys_refcursor;
  begin
    dijkstra(p_a => p_a);
    open l_ret_val for
      with tbl_flow as
       (select t.*
              ,utils_pkg.dist_between_points(p2x, p2y, p_b.x, p_b.y) dist_from_b
          from tmp_tbl_for_graph t),
      ways(id,
      d,
      s,
      iter,
      parent_id) as
       (
        --Ищем с минимальной стоимостью маршрута
        select t.id
               ,t.d  d
               ,t.s  s
               ,0    iter
               ,t.id parent_id
          from tbl_flow b
          join tmp_tbl_for_calc t on t.id = b.id
         where b.dist_from_b = (select min(dist_from_b)
                                  from tbl_flow)
        union all
        --От минимального ищем 
        select t.id
               ,t.d + tt.d
               ,t.s
               ,tt.iter + 1 iter
               ,tt.parent_id
          from ways             tt
               ,tmp_tbl_for_calc t
         where tt.s = t.id)
      select t.p1x  from_x
            ,t.p1y  from_y
            ,t.p2x  to_x
            ,t.p2y  to_y
            ,t.wifi
        from ways w
        join tmp_tbl_for_graph t on t.id = w.id
       where w.parent_id in (select parent_id
                               from ways w
                              where d = (select min(d)
                                           from ways
                                          where s = -1))
       order by iter desc;
    return l_ret_val;
  end;
  --Расчет кратчайших путей
  procedure dijkstra(p_a coordinate) is
    l_b coordinate;
    type points_t is table of number;
    l_t  points_t;
    iter number := 0;
    procedure initialize is
    begin
      insert into tmp_tbl_for_graph
        (id
        ,from_street
        ,to_street
        ,p1x
        ,p1y
        ,p2x
        ,p2y
        ,cost_flow
        ,wifi)
        select id
              ,null
              ,null
              ,p1x
              ,p1y
              ,p2x
              ,p2y
              ,cost_flow
              ,wifi
          from (select rownum id
                      ,p1x
                      ,p1y
                      ,p2x
                      ,p2y
                      ,cost_flow
                      ,wifi
                  from graph_flows)
         order by 4
                 ,5;
      --Ищем ближайшую точку от А и B
      insert into tmp_tbl_for_calc
        (id
        ,d
        ,s
        ,cons)
        with tbl_flow as
         (select id
                ,utils_pkg.dist_between_points(p1x, p1y, p_a.x, p_a.y) dist_from_a
            from tmp_tbl_for_graph t)
        select id
              ,0
              ,-1
              ,1
          from tbl_flow a
         where a.dist_from_a = (select min(dist_from_a)
                                  from tbl_flow);
      with tbl_flow as
       (select id
              ,utils_pkg.dist_between_points(p2x, p2y, l_b.x, l_b.y) dist_from_b
          from tmp_tbl_for_graph t)
      select id
        bulk collect
        into l_t
        from tbl_flow b
       where b.dist_from_b = (select min(dist_from_b)
                                from tbl_flow);
    end;
  begin
    initialize;
    --begin calc
    insert into tmp_tbl_for_calc
      (id
      ,d
      ,s
      ,cons)
      select pp.id
            ,calc_cost(pp.cost_flow, t.d, p.wifi)
            ,t.id
            ,0
        from tmp_tbl_for_calc t
        join tmp_tbl_for_graph p on t.id = p.id
        join tmp_tbl_for_graph pp on p.p2x = pp.p1x
                                 and p.p2y = pp.p1y;
    --
    loop
      declare
        l_tmp_id tmp_tbl_for_calc%rowtype;
      begin
        iter := iter + 1;
        exit when iter > 1000;
        select *
          into l_tmp_id
          from tmp_tbl_for_calc t
         where t.cons = 0
           and t.d = (select min(d)
                        from tmp_tbl_for_calc t
                       where cons = 0)
           and rownum = 1;
        --Устанавливаем постоянную метку
        update tmp_tbl_for_calc t
           set t.cons = 1
         where t.id = l_tmp_id.id;
        -- Обновляем расстояния
        merge into tmp_tbl_for_calc t
        using (select pp.id
                     ,l_tmp_id.d d
                     ,l_tmp_id.id s
                     ,calc_cost(l_tmp_id.d, pp.cost_flow, pp.wifi) cost_flow
                 from tmp_tbl_for_graph p
                 join tmp_tbl_for_graph pp on p.p2x = pp.p1x
                                          and p.p2y = pp.p1y
                where p.id = l_tmp_id.id) s
        on (t.id = s.id)
        when not matched then
          insert
            (id
            ,d
            ,s
            ,cons)
          values
            (s.id
            ,cost_flow
            ,s.s
            ,0)
        when matched then
          update
             set t.d = s.cost_flow
                ,t.s = s.s
           where t.d > s.cost_flow;
      exception
        when no_data_found then
          exit;
      end;
    end loop;
  end;
  --Расчет расстояния между точками
  function dist_between_points(p_x1 number
                              ,p_y1 number
                              ,p_x2 number
                              ,p_y2 number) return number is
  begin
    return(sqrt(power(p_x2 - p_x1, 2) + power(p_y2 - p_y1, 2)));
  end;

  --Расчет расстояния между точками
  function dist_between_points(p_a coordinate
                              ,p_b coordinate) return number is
  begin
    return(sqrt(power(p_b.x - p_a.x, 2) + power(p_b.y - p_a.y, 2)));
  end;
  --функция расчета растояния от точки до отрезка
  function dist_to_line(p_p  coordinate
                       ,p_p1 coordinate
                       ,p_p2 coordinate) return number is
    l_tmp number;
  begin
    l_tmp := ((p_p.x - p_p1.x) * (p_p2.x - p_p1.x) + (p_p.y - p_p1.y) * (p_p2.y - p_p1.y)) /
             (power(p_p2.x - p_p1.x, 2) + power(p_p2.y - p_p1.y, 2));
    l_tmp := case
               when l_tmp < 0 then
                0
               when l_tmp > 1 then
                1
               else
                l_tmp
             end;
    return sqrt(power((p_p1.x - p_p.x + (p_p2.x - p_p1.x) * l_tmp), 2) +
                power((p_p1.y - p_p.y + (p_p2.y - p_p1.y) * l_tmp), 2));
    --    return((p_p1.y - p_p2.y) * p_p.x + (p_p1.x - p_p2.x) * p_p.y + (p_p1.x * p_p2.y - p_p2.x * p_p1.y)) / dist_between_points(p_p1,
    --                                                                                                                            p_p2);
  end;
  --
  procedure add_street(p_name_street varchar2
                      ,p_first_x     number
                      ,p_first_y     number
                      ,p_second_x    number
                      ,p_second_y    number) is
    l_not_exists exception;
    pragma exception_init(l_not_exists, -00942);
  begin
    insert into streets
      (name_street
      ,first_x
      ,first_y
      ,second_x
      ,second_y
      ,p1
      ,p2)
    values
      (p_name_street
      ,p_first_x
      ,p_first_y
      ,p_second_x
      ,p_second_y
      ,coordinate(p_first_x, p_first_y)
      ,coordinate(p_second_x, p_second_y));
    commit;
  end;
  --
  procedure delete_street(p_id_street streets.id_street%type) is
  begin
    delete from streets
     where id_street = p_id_street;
    commit;
  end;
  --
  procedure delete_street(p_name streets.name_street%type) is
    l_id_street streets.id_street%type;
  begin
    select s.id_street
      into l_id_street
      from streets s
     where s.name_street = p_name;
    delete_street(l_id_street);
  exception
    when no_data_found then
      raise_application_error(-20000, 'No found street');
  end;
  --
  procedure add_wifi_point(p_name   varchar2
                          ,p_radius number
                          ,p_x      number
                          ,p_y      number) is
    l_not_exists exception;
    pragma exception_init(l_not_exists, -00942);
  begin
    insert into wifipoints
      (name_point
      ,radius
      ,x
      ,y
      ,p)
    values
      (p_name
      ,p_radius
      ,p_x
      ,p_y
      ,coordinate(p_x, p_y));
    commit;
  end;
  --
  procedure delete_point(p_id_point wifipoints.id_point%type) is
  begin
    delete from wifipoints
     where id_point = p_id_point;
    commit;
  end;
end utils_pkg;
/
create or replace force view  graph_flows as
with data_cross as
 (select s1.id_street from_street
        ,s2.id_street to_street
        ,s1.p1.x x1
        ,s1.p1.y y1
        ,s1.p2.x x2
        ,s1.p2.y y2
        ,s2.p1.x x3
        ,s2.p1.y y3
        ,s2.p2.x x4
        ,s2.p2.y y4
        ,(s2.p2.x - s1.p2.x) * (s2.p2.y - s2.p1.y) - (s2.p2.x - s2.p1.x) * (s2.p2.y - s1.p2.y) ua
        ,(s1.p1.x - s1.p2.x) * (s2.p2.y - s1.p2.y) - (s2.p2.x - s1.p2.x) * (s1.p1.y - s1.p2.y) ub
        ,(s2.p2.y - s2.p1.y) * (s1.p1.x - s1.p2.x) - (s2.p2.x - s2.p1.x) * (s1.p1.y - s1.p2.y) d
    from streets s1
        ,streets s2
   where s1.id_street != s2.id_street),
d_flow as
 (select from_street
        ,to_street
        ,x1
        ,y1
        ,x2
        ,y2
        ,x3
        ,y3
        ,x4
        ,y4
    from (select d.from_street
                ,d.to_street
                ,x1
                ,y1
                ,x2
                ,y2
                ,x3
                ,y3
                ,x4
                ,y4
                ,ua / d ua
                ,ub / d ub
            from data_cross d)
   where (ua >= 0 and ua <= 1)
     and (ub >= 0 and ub <= 1)),
calc_xy as
 (select from_street
        ,to_street
        ,x1
        ,y1
        ,x2
        ,y2
        ,x3
        ,y3
        ,x4
        ,y4
        ,x_cross
        ,case x4 - x3
           when 0 then
            0
           else
            ((y3 - y4) * x_cross - (x3 * y4 - x4 * y3)) / (x4 - x3)
         end y_cross
    from (select from_street
                ,to_street
                ,x1
                ,y1
                ,x2
                ,y2
                ,x3
                ,y3
                ,x4
                ,y4
                ,((x1 * y2 - x2 * y1) * (x4 - x3) - (x3 * y4 - x4 * y3) * (x2 - x1)) /
                 ((y1 - y2) * (x4 - x3) - (y3 - y4) * (x2 - x1)) x_cross
            from d_flow)),
cross_point as
 (select t.from_street
        ,t.to_street
        ,t.x1
        ,t.y1
        ,t.x2
        ,t.y2
        ,t.x3
        ,t.y3
        ,t.x4
        ,t.y4
        ,abs(t.x_cross) x_cross
        ,case
           when t.y_cross = 0 then
            t1.y_cross
           else
            t.y_cross
         end y_cross
    from calc_xy t
    join calc_xy t1 on t.from_street = t1.to_street
                   and t.to_street = t1.from_street)
--Получаем ребра графа
,
flows as
 (select x
        ,y
        ,to_x
        ,to_y
        ,t.id_street
        ,utils_pkg.dist_between_points(x, y, to_x, to_y) d
        ,case
           when t1.id_street is not null then
            1
           else
            0
         end wifi
    from (select x
                ,y
                ,id_street
                ,lead(x, 1) over(partition by id_street order by x, y) to_x
                ,lead(y, 1) over(partition by id_street order by x, y) to_y
            from (select first_x   x
                        ,first_y   y
                        ,id_street
                    from streets
                  union all
                  select second_x  x
                        ,second_y  y
                        ,id_street
                    from streets
                  union all
                  select distinct x_cross     x
                                 ,y_cross     y
                                 ,from_street id_street
                    from cross_point)) t
    left join list_street_with_wifi t1 on t.id_street = t1.id_street
   where to_x is not null
     and to_y is not null)
--Добавляем обратное направление
select distinct p1x
               ,p1y
               ,p2x
               ,p2y
               ,id_street
               ,cost_flow
               ,wifi
  from (select x         p1x
              ,y         p1y
              ,to_x      p2x
              ,to_y      p2y
              ,id_street
              ,d         cost_flow
              ,wifi
          from flows t
        union all
        select to_x      p1x
              ,to_y      p1y
              ,x         p2x
              ,y         p2y
              ,id_street
              ,d         cost_flow
              ,wifi
          from flows t);
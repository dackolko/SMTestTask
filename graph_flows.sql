create or replace view graph_flows as
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
        ,x_cross --TODO почему минус при вертикальном отрезке
        ,case x4 - x3
           when 0 then
            0
           else
            ((y3 - y4) * x_cross - (x3 * y4 - x4 * y3)) / (x4 - x3)
         end y_cross --TODO почему при разных соединениях 1 и 2 или 2 и 1 разные координаты(может быть 0)
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
get_point_cross as
 (select distinct t1.from_street
                 ,t1.to_street
                 ,t1.x1
                 ,t1.y1
                 ,t1.x2
                 ,t1.y2
                 ,t1.x3
                 ,t1.y3
                 ,t1.x4
                 ,t1.y4
                 ,abs(case t1.x_cross
                        when 0 then
                         t2.x_cross
                        else
                         t1.x_cross
                      end) x_cross
                 ,case t1.y_cross
                    when 0 then
                     t2.y_cross
                    else
                     t1.y_cross
                  end y_cross
    from calc_xy t1
    left join calc_xy t2 on t1.from_street = t2.to_street)
--Выбираем все точки, от точки пересечения до конечной и от конечной к точке пересечения - это и есть ребра графа
select from_street
      ,to_street
      ,x1 p1x
      ,y1 p1y
      ,x2 p2x
      ,y2 p2y
      ,utils_pkg.dist_between_points(x1, y1, x2, y2) cost_flow
      ,case
         when w.id_street is not null then
          1
         else
          0
       end wifi
  from (select from_street
              ,to_street
              ,x1
              ,y1
              ,x_cross     x2
              ,y_cross     y2
          from get_point_cross f
        union all
        select from_street
              ,to_street
              ,x_cross     x1
              ,y_cross     y1
              ,x2
              ,y2
          from get_point_cross
        union all
        select to_street   from_street
              ,from_street to_street
              ,x_cross     x1
              ,y_cross     y1
              ,x1 x2
              ,y1 y2
          from get_point_cross)
  left join (select distinct id_street
               from list_street_with_wifi) w on from_street = w.id_street;
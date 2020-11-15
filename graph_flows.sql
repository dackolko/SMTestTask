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
    left join calc_xy t2 on t1.from_street = t2.to_street) --TODO т.к. у нас не все правильно высчитывается- делаем костылем
,
--Выбираем все точки, от точки пересечения до конечной и от конечной к точке пересечения - это и есть ребра графа
flows as
 (select t1.from_street, t1.to_street, t1.x1 p1x, t1.y1 p1y, t1.x_cross p2x, t1.y_cross p2y 
    from get_point_cross t1
    join get_point_cross t2 on t1.from_street = t2.to_street and t2.from_street = t1.to_street
    union all
    select t1.from_street, t1.to_street, t2.x_cross p1x, t2.y_cross p1y, t2.x1 p2x, t2.y1 p2y 
    from get_point_cross t1
    join get_point_cross t2 on t2.from_street = t1.to_street and t1.from_street = t2.to_street
    )
select from_street, to_street, p1x, p1y, p2x, p2y, solver_pkg.dist_between_points(p1x, p1y, p2x, p2y) cost_flow
  from flows;
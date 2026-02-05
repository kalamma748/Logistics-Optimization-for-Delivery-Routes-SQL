#                            Task 1 : Data Cleaning & Preparation
#  identify duplicate records in orders and shipments tables
select Order_ID, count(*) as count from fedex_orders 
group by Order_ID having count(*)>1;
select Shipment_ID, count(*) as count from fedex_shipments 
group by Shipment_ID having count(*)>1;

#  Checking for null values
select * from fedex_shipments where delay_hours is null;

# Ensure that no Delivery_Date occurs before Pickup_Date 
select * from fedex_shipments where Pickup_Date > Delivery_Date;

#                                    Task 2: Delivery Delay Analysis
# delivery delay (in hours) for each shipment using Delivery_Date – Pickup_Date.
select Shipment_ID,timestampdiff(hour,Pickup_Date,Delivery_Date) as delay_hours
from fedex_shipments ;

#Top 10 delayed routes based on average delay hours.
SELECT Route_ID, round(AVG(Delay_Hours),2) as avg_delay_hours
FROM
    fedex_shipments
GROUP BY route_ID
ORDER BY avg_delay_hours DESC
LIMIT 10;

#SQL window functions to rank shipments by delay within each Warehouse_ID.
select Shipment_ID,Warehouse_ID,Delay_Hours,
rank() over (partition by Warehouse_ID order by Delay_Hours desc) as delay_rank from
fedex_shipments ;
 
#Identify the average delay per Delivery_Type (Express / Standard) to compare 
#service-level efficiency.
select delivery_type,round(avg(delay_hours),2) as avg_delay_hours 
from fedex_orders o join fedex_shipments s on o.Route_ID = s.Route_ID group by delivery_type;

#                                Task 3: Route Optimization Insights
#Average transit time (in hours) across all shipments. 
select s.shipment_ID,s.route_ID,r.Avg_Transit_Time_Hours from fedex_routes r
 join fedex_shipments s where r.Route_ID = s.Route_ID;
 
#Average delay (in hours) per route.
select route_ID,round(avg(delay_hours),2) as Avg_delay
from fedex_shipments group by route_ID order by Avg_delay desc;
 
#Distance-to-time efficiency ratio = Distance_KM / Avg_Transit_Time_Hours
select route_ID,round((distance_KM/Avg_Transit_Time_Hours),2) as Distance_to_time_efficiency
from fedex_routes;

#Identify 3 routes with the worst efficiency ratio (lowest distance-to-time).
select route_ID,round((distance_KM/Avg_Transit_Time_Hours),2) as Distance_to_time_efficiency
from fedex_routes order by Distance_to_time_efficiency limit 3;

#Find routes with >20% of shipments delayed beyond expected transit time. 
select s.route_ID,count(s.Shipment_ID) as Total_shipments,
r.Avg_Transit_Time_Hours,
sum(case when s.delay_hours > r.Avg_Transit_Time_Hours then 1 else 0 end)*100/count(s.Shipment_ID) as Shipments_delay_Per
from fedex_shipments s join fedex_routes r on s.Route_ID = r.Route_ID
group by s.route_ID,r.Avg_Transit_Time_Hours having Shipments_delay_Per > 20;

#                              Task 4: Warehouse Performance 
#Find the top 3 warehouses with the highest average delay in shipments dispatched
select Warehouse_ID,round(avg(Delay_Hours),2) as Avg_delay_hours
 from fedex_shipments group by Warehouse_ID order by Avg_delay_hours desc limit 3;
 
 # total shipments vs delayed shipments for each warehouse. 
 select Warehouse_ID,count(Shipment_ID) total_shipements,sum(case when Delay_Hours>0 then 1 else 0 end) as delay_shipments
 from fedex_shipments group by Warehouse_ID;
 
#CTEs to identify warehouses where average delay exceeds the global average delay.  
With CTE_Avg_delay as (
select Warehouse_ID,round(avg(Delay_Hours),2) as Avg_delay from fedex_shipments group by Warehouse_ID
)
select warehouse_ID,Avg_delay from CTE_Avg_delay
where Avg_delay > (select avg(Delay_Hours) as global_avg_delay from fedex_shipments) order by Avg_delay desc;  

#Rank all warehouses based on on-time delivery percentage.
with CTE_Warehouse_OTD as( 
select Warehouse_ID,count(Shipment_ID) as total_shipments,
sum(case when Delay_Hours = 0 then 1 else 0 end) as on_time_shipments,
sum(case when Delay_Hours = 0 then 1 else 0 end)*100/count(Shipment_ID) as on_time_delivery_percentage
from fedex_shipments group by Warehouse_ID)
select warehouse_ID,total_shipments,on_time_shipments,on_time_delivery_percentage,
rank() over (order by on_time_delivery_percentage desc) as warehouse_rank
from CTE_Warehouse_OTD order by warehouse_rank;

#                                    Task 5: Delivery Agent Performance
#Rank delivery agents (per route) by on-time delivery percentage. 
with CTE_agent_route_performance as
(select agent_ID,route_ID,count(Shipment_ID) as total_shipments,
sum(case when Delay_Hours = 0 then 1 else 0 end) as on_time_shipments,
sum(case when Delay_Hours = 0 then 1 else 0 end) * 100/count(Shipment_ID) as on_time_delivery_percentage
from fedex_shipments group by agent_ID,route_ID )
select agent_ID,route_ID,on_time_delivery_percentage,
dense_rank() over (partition by route_ID order by on_time_delivery_percentage desc) as agent_rank 
from CTE_agent_route_performance;

#Find agents whose on-time % is below 85%. 
select agent_ID,Route_ID,count(Shipment_ID) as total_shipments,
sum(case when Delay_Hours = 0 then 1 else 0 end) as on_time_shipments,
sum(case when Delay_Hours = 0 then 1 else 0 end) * 100/count(Shipment_ID) as on_time_delivery_percentage
from fedex_shipments group by agent_ID,Route_ID 
having on_time_delivery_percentage < 85 order by on_time_delivery_percentage desc;
 
#Compare the average rating and experience (in years) of the top 5 vs bottom 5 agents 
#using subqueries
with CTE_agent_performance as
(SELECT da.agent_ID,da.avg_Rating,da.Experience_Years,
ROUND(SUM(CASE WHEN Delay_Hours = 0 THEN 1 ELSE 0 END) * 100.0 
                / COUNT(*),2) AS on_time_pct 
from fedex_shipments s join fedex_delivery_agents da on s.agent_ID = da.Agent_ID 
group by 
s.agent_ID,da.Avg_Rating,da.Experience_Years)
select agent_ID,avg_Rating,Experience_Years from
(select agent_ID,avg_Rating,Experience_Years,
dense_rank() over (order by on_time_pct desc) as Agent_Rank
from CTE_agent_performance order by Agent_Rank asc limit 5 ) a
union all
select agent_ID,avg_Rating,Experience_Years from
(select agent_ID,avg_Rating,Experience_Years,
dense_rank() over (order by on_time_pct desc) as Agent_Rank
from CTE_agent_performance order by Agent_Rank desc limit 5 ) b;

#                                          Task 6: Shipment Tracking Analytics
#For each shipment, display the latest status (Delivered, In Transit, or Returned) along 
#with the latest Delivery_Date. 
SELECT
    Shipment_ID,
    Delivery_Status AS latest_status,
    Delivery_Date AS latest_delivery_date
FROM fedex_shipments;

#Identify routes where the majority of shipments are still “In Transit” or “Returned”. 
select route_ID,count(shipment_ID) as total_shipments,
sum(case when delivery_status in ('In Transit','Returned') then 1 else 0 end) as Transit_Returned_shipments
from fedex_shipments group by route_ID order by Transit_returned_shipments desc;

#Find the most frequent delay reasons (if available in delay-related columns or flags)
SELECT Delay_Reason,
    COUNT(*) AS delay_count
FROM fedex_shipments
WHERE Delay_Hours > 0
GROUP BY Delay_Reason
ORDER BY delay_count DESC;

#Identify orders with exceptionally high delay (>120 hours) to investigate potential 
#bottlenecks. 
select shipment_ID,order_ID,agent_ID,route_ID,Delivery_Status,delay_hours,Delay_Reason
from fedex_shipments where delay_hours > 120 order by delay_hours desc ;

#                                    Task 7: Advanced KPI Reporting
# Average Delivery Delay per Source_Country.
select r.Source_Country,round(avg(s.Delay_Hours),2) as avg_delay from fedex_shipments s inner join fedex_routes r
on s.route_ID = r.route_ID group by r.Source_Country order by avg_delay desc;

# On-Time Delivery % = (Total On-Time Deliveries / Total Deliveries) * 100
select (sum(case when Delay_Hours = 0  then 1 else 0 end)/count(*)) * 100 as on_time_delivery_pct
from fedex_shipments;

# Average Delay (in hours) per Route_ID.
select route_ID,round(avg(Delay_Hours),2) as Avg_delay from fedex_shipments group by route_ID order by Avg_delay desc;

# Warehouse Utilization % = (Shipments_Handled / Capacity_per_day) * 100. 
select s.warehouse_ID,count(s.Shipment_ID) as shipments_handled,w.Capacity_per_day,
(count(s.Shipment_ID)/w.Capacity_per_day) * 100 as warehouse_Uti_per
from fedex_warehouses w inner join fedex_shipments s on w.Warehouse_ID = s.Warehouse_ID
group by s.warehouse_ID,w.Capacity_per_day order by warehouse_Uti_per desc;

#                                  Video Link
# https://drive.google.com/file/d/1qJIjLnXoNunOn2BbfdgWs_MaRpsZi5aJ/view?usp=sharing





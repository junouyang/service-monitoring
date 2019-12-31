import sys
import time
import hashlib
import mysql.connector

if len(sys.argv) < 2:
    exit('not enough arguments!\n usage: python mock_metric.py application_prefix')

app_prefix = sys.argv[1]
app_name = app_prefix + "-upstream"


mysql = mysql.connector.connect(
    host="localhost",
    user="controller",
    passwd="controller",
    database="controller"
)


def run_sql(sql):
    cursor = mysql.cursor()
    cursor.execute(sql)
    return cursor.fetchall()


def update(*args):
    cursor = mysql.cursor()
    cursor.execute(*args)
    mysql.commit()


def query_single_value(sql):
    result = run_sql(sql)
    return result[0][0]


def query_latest_metric_data_by_id(metric_id):
    sql = 'select * from metricdata_min where metric_id = %d order by ts_min desc limit 1' % metric_id
    return run_sql(sql)


# clean data
update('''delete mm from metric m 
          left join metric_config_map mm on m.id = mm.metric_id
          where m.name like "%From:App:%|From:BT:%"''')
# update('''delete md from metricdata_min md
#           left join metric m on m.id = md.metric_id
#           where m.name like "%From:App:%|From:BT:%"''')
update('delete m from metric m where m.name like "%From:App:%|From:BT:%"')


def query_upstream_bt_ids():
    find_upstream_bt_sql = '''select bt.id from abusiness_transaction bt
                  left join application a on bt.application_id = a.id
                  where a.name = "%s"''' % app_name
    result = run_sql(find_upstream_bt_sql)
    return map(lambda row: row[0], result)


def replace_and_insert(table, value_tuple, replacement):
    values = [v for v in value_tuple]
    for key in replacement:
        values[key] = replacement[key]
    return insert_values(table, values)


def replace_and_insert_no_id(table, value_tuple, replacement):
    values = [v for v in value_tuple]
    for key in replacement:
        values[key] = replacement[key]
    return insert_values_no_id(table, values)


# create metrics for any metric like
#    BTM|BTs|BT:61|Exit Call:HTTP|From:App:28|From:31|Calls per Minute
# => BTM|BTs|BT:61|Exit Call:HTTP|From:App:28|From:31|From:BT:29|Calls per Minute
def create_metric(value_tuple, bt_id):
    new_metric_name = value_tuple[2]
    last_seg = new_metric_name.rindex("|")
    new_metric_name = new_metric_name[0:last_seg] + ("|From:BT:%d" % bt_id) + new_metric_name[last_seg:]
    metric_name_sha = hashlib.sha1(new_metric_name.lower().encode('utf-8')).hexdigest()
    return replace_and_insert('metric', value_tuple, {2: new_metric_name, 3: metric_name_sha}), new_metric_name


# create async metrics for any metric like
#    BTM|BTs|BT:61|Exit Call:HTTP|From:App:28|From:31|Calls per Minute
# => BTM|BTs|BT:61|Exit Call:HTTP|Async|From:App:28|From:31|From:BT:29|Calls per Minute
def create_async_metric(value_tuple, bt_id):
    new_metric_name = value_tuple[2]
    from_app_index = new_metric_name.rindex("|From:App")
    last_seg = new_metric_name.rindex("|")
    new_metric_name = new_metric_name[0:from_app_index] + \
                      "|Async" + new_metric_name[from_app_index:last_seg] + \
                      ("|From:BT:%d" % bt_id) + \
                      new_metric_name[last_seg:]
    metric_name_sha = hashlib.sha1(new_metric_name.lower().encode('utf-8')).hexdigest()
    return replace_and_insert('metric', value_tuple, {2: new_metric_name, 3: metric_name_sha}), new_metric_name


def insert_values(table, values):
    max_id = query_single_value('select max(id) from %s' % table)
    values[0] = max_id + 1
    insert_sql = "insert into %s values " % table
    update(insert_sql + str(tuple(values)).replace(', None,', ', null,'))
    return values[0]


def insert_values_no_id(table, values):
    insert_sql = "insert ignore into %s values " % table
    sql = insert_sql + str(tuple(values)).replace(', None,', ', null,')
    update(sql)
    return values[0]


def insert_metric_data_agg(parent_data, metric_id, minute):
    sql = "insert ignore into metricdata_min_agg values (%d, %d, %d, %d, %d, %d, %d, %d, %d, %d)" \
                 % (minute, metric_id, parent_data[5], parent_data[6], 100, parent_data[7], parent_data[8],
                    parent_data[9], parent_data[10], parent_data[11])
    update(sql)
    return parent_data[0]


def insert_metric_data_agg_app(parent_data, metric_id, minute):
    sql = "insert ignore into metricdata_min_agg_app values (%d, %d, %d, %d, %d, %d, %d, %d, %d)" \
                 % (minute, metric_id, parent_data[6], 100, parent_data[7], parent_data[8], parent_data[9],
                    parent_data[10], parent_data[11])
    update(sql)
    return parent_data[0]


def to_array(value_tuple):
    return [v for v in value_tuple]


def split_count(count):
    return int((count - 3) / 3)


def create_metric_data(metric_id, metric_name, parent_metric_id):
    parent_metric_data = run_sql("select * from metricdata_min where metric_id = %s order by ts_min desc limit 1" % parent_metric_id)

    if len(parent_metric_data) == 0:
        return

    parent_metric_data = parent_metric_data[0]

    replacement = {1: metric_id}
    if "Response Time" in metric_name:
        replacement[7] = split_count(parent_metric_data[7])
    else:
        for i in range(8, 12):
            replacement[i] = split_count(parent_metric_data[i])

    max_ts_min = query_single_value("select max(ts_min) from metricdata_min where metric_id = %s" % parent_metric_id)
    max_ts_min = max(max_ts_min, int(time.time() / 60))
    for minute in range(-240, 24 * 60):
        replacement[0] = max_ts_min + minute
        replace_and_insert_no_id("metricdata_min", parent_metric_data, replacement)
        insert_metric_data_agg(parent_metric_data, metric_id, max_ts_min + minute)
        insert_metric_data_agg_app(parent_metric_data, metric_id, max_ts_min + minute)


def create_sync_metrics(metric, upstream_app_id, upstream_bt_id):
    metric_id, metric_name = create_metric(metric, upstream_bt_id)

    create_metric_association_and_data(metric, metric_id, metric_name, upstream_app_id, upstream_bt_id)


def create_async_metrics(metric, upstream_app_id, upstream_bt_id):
    metric_id, metric_name = create_async_metric(metric, upstream_bt_id)

    create_metric_association_and_data(metric, metric_id, metric_name, upstream_app_id, upstream_bt_id)


def create_metric_association_and_data(metric, metric_id, metric_name, upstream_app_id, upstream_bt_id):
    # create metric_config_map same as existing cross app metrics
    metric_config_maps = run_sql("select * from metric_config_map where metric_id = %d" % metric[0])
    for metric_config_map in metric_config_maps:
        replace_and_insert("metric_config_map", metric_config_map, {5: metric_id})
    # associate the metrics with upstream bt.
    insert_values("metric_config_map", [0, 0, "BT_PERF", "BUSINESS_TRANSACTION", upstream_bt_id, metric_id])
    # associate the metrics with upstream app.
    insert_values("metric_config_map", [0, 0, "BT_PERF", "APPLICATION", upstream_app_id, metric_id])
    # create metric data
    create_metric_data(metric_id, metric_name, metric[0])
    print("created metric: %s" % metric_name)


if __name__ == '__main__':
    sql_related_bts = '''select count(*) from metricdata_min md
                         left join metric m on md.metric_id = m.id 
                         left join metric_config_map mm on mm.metric_id = m.id and mm.config_entity_type = "application_component" 
                         left join application_component ac on ac.id = mm.config_entity_id
                         left join application a on a.id = ac.application_id 
                         where m.name like "BTM|BTs|BT:%%|From:App:%%|From:%%" and a.name like "%s%%"''' % app_prefix
    while query_single_value(sql_related_bts) < 6:
        print("Cross app metrics are not ready yet.")
        time.sleep(5)

    query_upstream_application_id = 'select id from application where name="%s"' % app_name

    upstream_app_id = query_single_value(query_upstream_application_id)

    cross_app_metric_name = 'BTM|BTs|BT:%%|From:App:%s|From:%%' % upstream_app_id

    find_cross_app_metric_by_name = 'select * from metric where name like "%s"' % cross_app_metric_name

    upstream_bt_ids = to_array(query_upstream_bt_ids())

    for metric in run_sql(find_cross_app_metric_by_name):

        parent_metric_name = metric[2]
        print("=" * 100)
        print("parent metric: %s" % parent_metric_name)
        print("-" * 5)

        for upstream_bt_id in upstream_bt_ids:
            create_sync_metrics(metric, upstream_app_id, upstream_bt_id)
            create_async_metrics(metric, upstream_app_id, upstream_bt_id)


    print("\n\nDone!")

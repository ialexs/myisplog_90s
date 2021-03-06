#!/bin/bash
# Quick Report Does My ISP Sucks
# useful for complain to their cs

echo -e "\nReport created with $1 back interval\n(one interval = 15 mins)"
#echo -e "How many interval back to report?\n(one interval = 15mins)"
#read biji

points=$1
hours=$(bc -l <<< "scale=1;(15*$points)/60")

# plot with feedgnuplot
plots()
{
< speedtest_log_short_fixed.csv cut -d, -f2,4,5 --output-delimiter=" " | \
	tail -n $points | \
	sed -e 's/+07:00//g' | \
	feedgnuplot --domain \
	--timefmt "%Y-%m-%d %H:%M:%S" \
	--set 'format x "%H:%M"' \
	--with "lines lw 2" \
	--legend 0 "Download" \
	--legend 1 "Upload"  \
	--set 'key outside'  \
	--xlabel "\nChart created: `date "+%a, %d/%b/%Y  %T %Z"` \n(using Speedtest.net - Interval 15min)\n\nBiznetHome CustomerID: " \
	--ylabel "MBps" \
	--set grid \
	--hardcopy qr-dataframe.png \
	--set "terminal png size 800,340"

echo -e "\nPlot chart.. done"
}

# Export existing data to a nice HTML
# using Panda's to_html()
df2html="
import pandas as pd

# Import csv log
df = pd.read_csv('speedtest_log_short_fixed.csv')

df.rename(columns={
    'timestamp':'Timestamp',
    'ping.latency':'Ping (ms)',
    'download.bandwidth':'Download<br>(Mbps)',
    'upload.bandwidth':'Upload<br>(Mbps)',
    'packetLoss':'Packet Loss',
    'isp':'ISP',
    'server.name':'Test Server',
    'result.url':'Speedtest.net URL'
                  }, inplace=True)

df[['Timestamp','Ping (ms)',
    'Download<br>(Mbps)',
    'Upload<br>(Mbps)',
    'Packet Loss','ISP',
    'Test Server',
    'Speedtest.net URL']].tail($points).to_html('qr-dataframe.html',
                    render_links=True,
                    border=1,
                    col_space=20,
                    justify='center', escape=False)
"

# Upload to S3
s3upload(){
	aws --profile ialexs_gmail s3 cp index.html s3://myisplog/
	aws --profile ialexs_gmail s3 cp qr-dataframe.png s3://myisplog/
	echo -e "\nUpload to S3.. done"
}

plots
python -c "$df2html"
cat qr-header.html > index.html
echo "<h3><marquee><img align="left" src="qr-new.gif">Chart created: `date "+%a, %d/%b/%Y  %T %Z"` - Data previous ~$hours hours</marquee></h3>" >> index.html
cat qr-dataframe.html qr-footer.html >> index.html
s3upload

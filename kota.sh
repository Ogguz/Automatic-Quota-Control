#!/bin/bash

REPORT_DIR='/opt/scripts/kota/quota_reports'
SERVER_CONN_CONF='/opt/scripts/kota/server_connection.conf'
DOMAIN_INFO='/opt/scripts/kota/domain_infos.conf'

die() {
    echo "$*" >&2
    exit 2
}

warn() {
    echo "$*" >&1
}

read_server_conn_conf() {

    if [[ ! -e $SERVER_CONN_CONF ]]; then
        die "$SERVER_CONN_CONF file doesnt exist!"
    fi

    echo "$SERVER_CONN_CONF file is reading... "

    while IFS= read -r line; do
      line=${line%%#*}
      case $line in *=*)
      var=${line%%=*}
      case $var in *[!A-Z_a-z]*)
          warn "$var is a freak"
          continue;;
      esac
      if eval '[ -n "${'$var'+1}" ]'; then
        warn "$var, where were you bro?"
        continue
      fi
      line=${line#*=}
      eval $var='"$line"'
      esac
    done <"$SERVER_CONN_CONF"

    warn "$SERVER_CONN_CONF has been discovered, next station is moon..."

}

ssh_via_domains() {
    
    if [[ ! -e $DOMAIN_INFO ]]; then
        die "Where the heck is $DOMAIN_INFO?? "
    fi

    domain_name=($(awk 'NR>1 {print $1}' $DOMAIN_INFO || die "$DOMAIN_INFO'dan alan adlari okunamadi.")) 

    email_usage=($(awk 'NR>1 {print "du -h " $2}' $DOMAIN_INFO | ssh $SUNUCU_EPOSTA_SSH_USER@$SUNUCU_EPOSTA 'bash -s' | awk '{print $1}' || die "Eposta boyutu okunamadi" )) 

    web_usage=($(awk 'NR>1 {print "du -h " $3}' $DOMAIN_INFO | ssh $SUNUCU_WEB_SSH_USER@$SUNUCU_WEB 'bash -s' | awk '{print $1}' || die "Web boyutu okunamadi." )) 

    db_usage=($(awk 'NR>1 {print "du -h " $4}' $DOMAIN_INFO | ssh $SUNUCU_MYSQL_SSH_USER@$SUNUCU_MYSQL_HOST 'bash -s' | awk '{print $1}' || die "Veritabani boyutu okunamadi." ))

}

humanity_is_over() {

  for v in "${@:-$(</dev/stdin)}"
  do  
    echo $v | awk \
      'BEGIN{IGNORECASE = 1}
       function printpower(n,b,p) {printf "%u\n", n*b^p; next}
       /[0-9]$/{print $1;next};
       /K(iB)?$/{printpower($1,  2, 10)};
       /M(iB)?$/{printpower($1,  2, 20)};
       /G(iB)?$/{printpower($1,  2, 30)};
       /T(iB)?$/{printpower($1,  2, 40)};
       /KB$/{    printpower($1, 10,  3)};
       /MB$/{    printpower($1, 10,  6)};
       /GB$/{    printpower($1, 10,  9)};
       /TB$/{    printpower($1, 10, 12)}'
  done

} 

i_am_a_human_afterall() {

    b=${1:-0}; d=''; s=0; S=(Bytes {K,M,G,T,P,E,Z,Y})
    while ((b > 1024)); do
        d="$(printf ".%02d" $((b % 1024 * 100 / 1024)))"
        b=$((b / 1024))
        let s++
    done
    echo "$b$d ${S[$s]}"
}

html_output(){

    date=$(date +%Y%m%d_%H-%M)
     
    output=$REPORT_DIR/kota-$date.html

    echo '<!DOCTYPE html>
          <html>
          <head>
          <style>
            table, th, td {
            border: 1px solid black;
            border-collapse: collapse;
            }
          </style>
          </head>
          <body>

          <h2> Domain Name Based Usage Table </h2>

          <table style="width:100%">
          <tr>
            <th>Domain Name</th>
            <th>E-Mail-Server Usage</th>
            <th>Web-Server Usage</th>
            <th>Database Usage</th>
            <th>Total Usage</th>
          </tr>
         ' >> $output

    count=$(wc -l $DOMAIN_INFO | awk '{print $1}')

    for (( i=0; i<$count; i++ )) do

       echo "<td>" ${domain_name[$i]} "</td>" >> $output
       echo "<td>" ${email_usage[$i]} "</td>" >> $output
       echo "<td>" ${web_usage[$i]} "</td>" >> $output
       echo "<td>" ${db_usage[$i]} "</td>" >> $output
       
       if [[ ! -z ${domain_name[$i]} ]]; then
           a=$(humanity_is_over ${email_usage[$i]}) 
           b=$(humanity_is_over ${web_usage[$i]}) 
           c=$(humanity_is_over ${db_usage[$i]})
           echo "<td>" >> $output
           d=$(($a+$b+$c))
           e=$(i_am_a_human_afterall $d)
           echo $e >> $output
       fi
       echo "</td> </tr> </body> </html>" >> $output

   done

}

reports_file() {

    if [[ ! -d $REPORT_DIR ]]; then

        mkdir $REPORT_DIR 2>/dev/null  || die "$REPORT_DIR needs to be created but somehow couldnt"

    fi

    warn "$REPORT_DIR has been checked/created..."

}

main() {

reports_file

read_server_conn_conf

ssh_via_domains

html_output

warn "$output is ready..."

exit 0

}

# root check 

if [[ $EUID == 0 ]]; then
    main
else
    die "$0 requires root privileges..."
fi

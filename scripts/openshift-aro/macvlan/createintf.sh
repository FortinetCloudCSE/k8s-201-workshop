for node in $(oc get nodes -o jsonpath='{.items[*].metadata.name}'); do 
  oc debug node/${node} -- bash -c "ip link add link eth0 name eth0.1000 type vlan id 1000 && ip link set eth0.1000 up"
done


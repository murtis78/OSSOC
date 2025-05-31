#!/usr/bin/env python3
"""
XML to JSON Converter for Nmap Reports
Converts Nmap XML output to structured JSON format for VulnWhisperer
"""

import sys
import json
import xml.etree.ElementTree as ET
from datetime import datetime
import argparse

def parse_nmap_xml(xml_file):
    """Parse Nmap XML file and convert to structured format"""
    try:
        tree = ET.parse(xml_file)
        root = tree.getroot()
    except ET.ParseError as e:
        print(f"Error parsing XML: {e}", file=sys.stderr)
        return None
    except FileNotFoundError:
        print(f"File not found: {xml_file}", file=sys.stderr)
        return None
    
    # Initialize result structure
    result = {
        "scan_info": {},
        "hosts": [],
        "stats": {},
        "metadata": {
            "scanner": "nmap",
            "converted_at": datetime.now().isoformat(),
            "source_file": xml_file
        }
    }
    
    # Parse scan info
    scaninfo = root.find('scaninfo')
    if scaninfo is not None:
        result["scan_info"] = {
            "type": scaninfo.get('type', ''),
            "protocol": scaninfo.get('protocol', ''),
            "numservices": scaninfo.get('numservices', ''),
            "services": scaninfo.get('services', '')
        }
    
    # Parse run stats
    runstats = root.find('runstats')
    if runstats is not None:
        finished = runstats.find('finished')
        hosts = runstats.find('hosts')
        
        if finished is not None:
            result["stats"]["finished"] = {
                "time": finished.get('time', ''),
                "timestr": finished.get('timestr', ''),
                "elapsed": finished.get('elapsed', ''),
                "summary": finished.get('summary', ''),
                "exit": finished.get('exit', '')
            }
        
        if hosts is not None:
            result["stats"]["hosts"] = {
                "up": hosts.get('up', '0'),
                "down": hosts.get('down', '0'),
                "total": hosts.get('total', '0')
            }
    
    # Parse hosts
    for host in root.findall('host'):
        host_data = parse_host(host)
        if host_data:
            result["hosts"].append(host_data)
    
    return result

def parse_host(host_elem):
    """Parse individual host information"""
    host_data = {
        "addresses": [],
        "hostnames": [],
        "status": {},
        "ports": [],
        "os": {},
        "scripts": [],
        "uptime": {},
        "trace": {}
    }
    
    # Parse addresses
    for address in host_elem.findall('address'):
        host_data["addresses"].append({
            "addr": address.get('addr', ''),
            "addrtype": address.get('addrtype', ''),
            "vendor": address.get('vendor', '')
        })
    
    # Parse hostnames
    hostnames_elem = host_elem.find('hostnames')
    if hostnames_elem is not None:
        for hostname in hostnames_elem.findall('hostname'):
            host_data["hostnames"].append({
                "name": hostname.get('name', ''),
                "type": hostname.get('type', '')
            })
    
    # Parse status
    status = host_elem.find('status')
    if status is not None:
        host_data["status"] = {
            "state": status.get('state', ''),
            "reason": status.get('reason', ''),
            "reason_ttl": status.get('reason_ttl', '')
        }
    
    # Parse ports
    ports_elem = host_elem.find('ports')
    if ports_elem is not None:
        for port in ports_elem.findall('port'):
            port_data = parse_port(port)
            if port_data:
                host_data["ports"].append(port_data)
    
    # Parse OS detection
    os_elem = host_elem.find('os')
    if os_elem is not None:
        host_data["os"] = parse_os(os_elem)
    
    # Parse host scripts
    hostscript = host_elem.find('hostscript')
    if hostscript is not None:
        for script in hostscript.findall('script'):
            script_data = parse_script(script)
            if script_data:
                host_data["scripts"].append(script_data)
    
    # Parse uptime
    uptime = host_elem.find('uptime')
    if uptime is not None:
        host_data["uptime"] = {
            "seconds": uptime.get('seconds', ''),
            "lastboot": uptime.get('lastboot', '')
        }
    
    return host_data

def parse_port(port_elem):
    """Parse port information"""
    port_data = {
        "portid": port_elem.get('portid', ''),
        "protocol": port_elem.get('protocol', ''),
        "state": {},
        "service": {},
        "scripts": []
    }
    
    # Parse state
    state = port_elem.find('state')
    if state is not None:
        port_data["state"] = {
            "state": state.get('state', ''),
            "reason": state.get('reason', ''),
            "reason_ttl": state.get('reason_ttl', '')
        }
    
    # Parse service
    service = port_elem.find('service')
    if service is not None:
        port_data["service"] = {
            "name": service.get('name', ''),
            "product": service.get('product', ''),
            "version": service.get('version', ''),
            "extrainfo": service.get('extrainfo', ''),
            "method": service.get('method', ''),
            "conf": service.get('conf', ''),
            "cpe": []
        }
        
        # Parse CPE entries
        for cpe in service.findall('cpe'):
            if cpe.text:
                port_data["service"]["cpe"].append(cpe.text)
    
    # Parse scripts
    for script in port_elem.findall('script'):
        script_data = parse_script(script)
        if script_data:
            port_data["scripts"].append(script_data)
    
    return port_data

def parse_script(script_elem):
    """Parse script information"""
    script_data = {
        "id": script_elem.get('id', ''),
        "output": script_elem.get('output', ''),
        "elements": []
    }
    
    # Parse script elements/tables
    for elem in script_elem.findall('elem'):
        script_data["elements"].append({
            "key": elem.get('key', ''),
            "value": elem.text or ''
        })
    
    for table in script_elem.findall('table'):
        table_data = parse_script_table(table)
        if table_data:
            script_data["elements"].append(table_data)
    
    return script_data

def parse_script_table(table_elem):
    """Parse script table elements"""
    table_data = {
        "type": "table",
        "key": table_elem.get('key', ''),
        "elements": []
    }
    
    for elem in table_elem.findall('elem'):
        table_data["elements"].append({
            "key": elem.get('key', ''),
            "value": elem.text or ''
        })
    
    return table_data

def parse_os(os_elem):
    """Parse OS detection information"""
    os_data = {
        "portused": [],
        "osmatch": [],
        "osfingerprint": []
    }
    
    # Parse ports used for OS detection
    for portused in os_elem.findall('portused'):
        os_data["portused"].append({
            "state": portused.get('state', ''),
            "proto": portused.get('proto', ''),
            "portid": portused.get('portid', '')
        })
    
    # Parse OS matches
    for osmatch in os_elem.findall('osmatch'):
        match_data = {
            "name": osmatch.get('name', ''),
            "accuracy": osmatch.get('accuracy', ''),
            "line": osmatch.get('line', ''),
            "osclass": []
        }
        
        for osclass in osmatch.findall('osclass'):
            match_data["osclass"].append({
                "type": osclass.get('type', ''),
                "vendor": osclass.get('vendor', ''),
                "osfamily": osclass.get('osfamily', ''),
                "osgen": osclass.get('osgen', ''),
                "accuracy": osclass.get('accuracy', ''),
                "cpe": [cpe.text for cpe in osclass.findall('cpe') if cpe.text]
            })
        
        os_data["osmatch"].append(match_data)
    
    # Parse OS fingerprints
    for osfingerprint in os_elem.findall('osfingerprint'):
        os_data["osfingerprint"].append({
            "fingerprint": osfingerprint.get('fingerprint', '')
        })
    
    return os_data

def main():
    parser = argparse.ArgumentParser(description='Convert Nmap XML to JSON')
    parser.add_argument('xml_file', help='Input XML file')
    parser.add_argument('json_file', help='Output JSON file')
    parser.add_argument('--pretty', action='store_true', help='Pretty print JSON')
    
    args = parser.parse_args()
    
    # Parse XML
    result = parse_nmap_xml(args.xml_file)
    
    if result is None:
        sys.exit(1)
    
    # Write JSON
    try:
        with open(args.json_file, 'w') as f:
            if args.pretty:
                json.dump(result, f, indent=2, sort_keys=True)
            else:
                json.dump(result, f)
        
        print(f"Successfully converted {args.xml_file} to {args.json_file}")
        
    except IOError as e:
        print(f"Error writing JSON file: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
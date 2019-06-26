import csv, os, sys, re
from argparse import ArgumentParser
csv.field_size_limit(sys.maxsize)



def chk_domain(t):
    '''Returns domain without final period or False if t not a valid domain name.'''
    pattern = re.compile(r'([a-z|A-Z|0-9]+[\w|\-\_]*?[a-z|A-Z|0-9]+)')
    try:
        if t[-1] == '.':
            t = t[:-1]
        toctets = t.split('.')
        output = list()
        for t in toctets:
            gp = re.match(pattern,t)
            if gp and t == gp[0]:
                output.append(t)           
            else:
                return None
                break
        else:
            return ".".join(output)
    except Exception as ex:
        print(ex)
        return None


def is_IP(ip_address):
    '''Returns True if ips is a string for a valid IP'''
    try:
        octets = ip_address.split('.')
        if len(octets) != 4:
            return False
        for oct in octets:
            if not oct.isdigit():
                return False
            if str(int(oct)) != oct  or int(oct) not in range(256):
                return False
        else:
            return True
    except Exception as ex:
        print(ex)
        return False

def main(dnsfile,outfile):
    fieldnames = ['qname','rdata']
    with open(dnsfile, newline='') as csvread:
        csvreader = csv.DictReader(csvread, delimiter = '\t')
        with open(outfile, 'w') as csvwrite:
            csvwriter = csv.DictWriter(csvwrite, fieldnames=fieldnames, extrasaction='ignore')
            csvwriter.writeheader()
            for idx,row in enumerate(csvreader):
                try:
                    if chk_domain(row['qname'])and is_IP(row['rdata']):
                        row['qname'] = chk_domain(row['qname'])
                        csvwriter.writerow(row)
                except Exception as ex:
                    print(ex)
                    pass
    return


if __name__ == '__main__':

    parser = ArgumentParser(description="Preprocess DNS data to a two column csv file: qname, rdata")
    parser.add_argument("dnspath",help="Filepath of DNS data")
    parser.add_argument("outputpath", help="Filepath where output will be directed")

    args= parser.parse_args()

    dnsfile = args.dnspath
    outfile = args.outputpath

    main(dnsfile, outfile)








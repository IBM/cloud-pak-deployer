import csv
import sys,os

#Usage: ./image-csv-trim.py [search_path] [desired_arch] [images-to-ignore, column separated string]; arch includes: amd64, ppc64le, s390x; 
desired_image_types=["olm-catalog","olm-bundle"]

def trim_csv(csv_file,desired_arch,images_to_keep):
    print(f"Trimming {csv_file} to preserve {desired_arch} images")
    alternative_arch=None
    if desired_arch=="amd64":
        alternative_arch="x86_64"
    trimmed_rows=[]
    with open(csv_file) as f:
        reader = csv.reader(f)
        for row in reader:
            image_name=row[1]
            image_arch=row[6]
            image_type=row[10]
            if image_arch==desired_arch or image_arch==alternative_arch or image_arch=='' or image_type in desired_image_types or image_name in images_to_keep:
                trimmed_rows.append(row)

    with open(csv_file,"w") as f:
        writer = csv.writer(f)
        writer.writerows(trimmed_rows)



if len(sys.argv)<3:
    print("Usage: ./image-csv-trim.py [search_path] [desired_arch]", file=sys.stderr)
    sys.exit(1)
search_path=sys.argv[1]
desired_arch=sys.argv[2]
image_to_skip_raw=""
if len(sys.argv)>3:
    image_to_skip_raw=sys.argv[3]
images_to_keep=image_to_skip_raw.split(",")

for fname in os.listdir(search_path):
    if fname.endswith("images.csv"):
        trim_csv(os.path.join(search_path,fname),desired_arch,images_to_keep)
import os
from re import findall
from shutil import move

orig_data = "/project/bbl_roalf_cmroicest/orig_data"
data = "/project/bbl_roalf_cmroicest/data"

os.system("printf 'original_name,new_name\n' >> tracker.csv")

for group in os.listdir(orig_data):
    if group == "Nonsmokers":
        code = 100000
    elif group == "Smokers":
        code = 200000
    else:
        continue

    group_dir = os.path.join(orig_data, group)
    for img in os.listdir(group_dir):

        if "Subj" not in img:
            continue

        # get subject number and add to code
        subject = findall(r'\d+', img)[-1]
        subject = code + int(subject)
        subject_dir = os.path.join(data, str(subject))
        if not os.path.exists(subject_dir):
            os.mkdir(subject_dir)

        # give new name to the img
        file_type = img.split('_')[0]
        if "glucestmap" == file_type:
            file_type = "B0B1CESTMAP"
        else:
            file_type = file_type.upper()


        new_name = str(subject) + "_" + file_type
        img_dir = os.path.join(group_dir, img)

        if not os.path.isdir(img):
            new_dcm_dir = os.path.join(subject_dir, new_name)
            os.mkdir(new_dcm_dir)
            move(img_dir, os.path.join(new_dcm_dir, new_name + ".dcm"))

        else:
            move(img_dir, subject_dir)

        # keep track of change in names
        track = "'" + img + "," + new_name + "\n'"
        os.system("printf " + track + " >> tracker.csv")

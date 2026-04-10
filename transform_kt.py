import sys
import os
import pandas as pd
import numpy as np

# define default origin point for transformation
DEFAULT_ORIGIN_POINT = 3

def display_help():
    print("Usage: python transform_kt.py <file/path> <origin_point>")
    print("<file/path> can be Excel (.xlsx) file or a folder of (.xlsx)")
    print("<origin_point> for transformation: pole 1, 2 or 3 for mid-point (default=3)")
    sys.exit(1)

def process_excel_file(file_path, origin_point):
    try:
        df_dict = pd.read_excel(file_path, None)        
        # load centrosome + kinetochore data, merge into single dataframe
        dff = assemble_filtered_dataframe(df_dict)
        # transform into centrosome-oriented basis
        dffp = align_points_to_centrosome_triple(dff, origin_point)
        # write out as .csv
        csv_file = os.path.splitext(file_path)[0] + f"_origin{origin_point}.csv"
        dffp.to_csv(csv_file, index=False)
        print(f"Exported: {csv_file}")
    except Exception as e:
        print(f"Error processing file {file_path}: {e}")

def process_folder(folder_path, origin_point):
    for file_name in os.listdir(folder_path):
        if file_name.endswith(".xlsx"):
            file_path = os.path.join(folder_path, file_name)
            process_excel_file(file_path, origin_point)

# function definitions for data processing

def concat_sheet_dataframes(df_dict):
    """concat sheet dataframes, adding sheet 'name' column"""
    df_list = []
    for sheet, dfs in df_dict.items():
        dfs.rename(columns={'Unnamed: 0': 't'}, inplace=True)  # column 0 is time 't'
        dfs['name'] = sheet
        df_list.append(dfs)
    return pd.concat(df_list)


def assemble_filtered_dataframe(df_dict):
    """concatenate dataframes for all points and exclude timepoints with undefined centrosome triple"""
    # keep only data from rows where name is Cn, Cn, Cmidpoint+1 or Kn
    df_raw = concat_sheet_dataframes(df_dict)
    names = df_raw['name']
    point_rows = names.str.match(r'(C|K)([0-9]+|midpoint\+1)', case=True, flags=0, na=None)
    df = df_raw.loc[point_rows].copy()

    # add point type to dataframe
    df['point_type'] = 'Undefined'
    names = df['name']
    Ctriple_rows = names.str.match("C")
    Kt_rows = names.str.match("K")
    df.loc[Ctriple_rows, 'point_type'] = 'Ctriple'
    df.loc[Kt_rows, 'point_type'] = 'Kt'

    # filter dataframe to exlude timepoints where centrosome+1 point triple undefined
    df3 = df[df['name'].isin(['C1', 'C2', 'Cmidpoint+1'])]
    t_C1_defined = df[df['name'] == 'C1'].dropna()['t']
    t_C2_defined = df[df['name'] == 'C2'].dropna()['t']
    t_mid_defined = df[df['name'] == 'Cmidpoint+1'].dropna()['t']
    t_any = set(t_C1_defined.to_list() + t_C2_defined.to_list() + t_mid_defined.to_list())
    t_triple_defined = [t for t in t_any if t in t_C1_defined.values and t in t_C2_defined.values and t in t_mid_defined.values]
    dff = df[df['t'].isin(t_triple_defined)]
    
    return dff


def align_interpolar_to_Y(interpolar_row_vector, point_coords):
    """
    calculate rotation matrix to align interpolar vector with Y axis and rotate all point_coords about origin
    see: https://uk.mathworks.com/matlabcentral/answers/1728115-how-to-align-any-vector-with-a-specified-axis-through-rotations
    """
    v = interpolar_row_vector
    y_axis = np.array([0, 1, 0])

    # Determine angle between the vector and x-axis
    theta = np.arccos(np.dot(v, y_axis)/(np.linalg.norm(v) * np.linalg.norm(y_axis)))

    # Determine the axis of rotation
    axis = np.cross(v, y_axis) / np.linalg.norm(np.cross(v, y_axis))

    # Construct rotation matrix using Rodrigues' formula
    K = np.array([[0, -axis[2], axis[1]], [axis[2], 0, -axis[0]], [-axis[1], axis[0], 0]])
    R = np.eye(3) + np.sin(theta)*K + (1 - np.cos(theta))*np.matmul(K, K)

    # Apply rotation matrix to points
    return np.matmul(R, point_coords.T).T


def realign_OM_to_Z(OM_row_vector, point_coords):
    """
    calculate rotation matrix to align interpolar vector with XZ component of Ori->Cmid+1 
    and rotate all point_coords about origin
    see: https://uk.mathworks.com/matlabcentral/answers/1728115-how-to-align-any-vector-with-a-specified-axis-through-rotations
    """
    v = OM_row_vector
    z_axis = np.array([0, 0, 1])

    # Determine angle between the vector and x-axis
    theta = np.arccos(np.dot(v, z_axis)/(np.linalg.norm(v) * np.linalg.norm(z_axis)))

    # Determine the axis of rotation
    axis = np.cross(v, z_axis) / np.linalg.norm(np.cross(v, z_axis))

    # Construct rotation matrix using Rodrigues' formula
    K = np.array([[0, -axis[2], axis[1]], [axis[2], 0, -axis[0]], [-axis[1], axis[0], 0]])
    R = np.eye(3) + np.sin(theta)*K + (1 - np.cos(theta))*np.matmul(K, K)

    # Apply rotation matrix to points
    return np.matmul(R, point_coords.T).T


def align_points_to_centrosome_triple(dff, origin_point):
    """
    return dffp (dff') , i.e. dff transformed into new basis, 
    - translate so midpoint is x=y=z=0
    - rotate inter-polar axis to align with Y
    - rotate so XZ component of midpoint-to-midpoint+1 vector aligns along Z
    - optionally translate one of poles to x=y=z=0
    """

    # carry out in 3 steps, one point at a time

    # step 1: translate and align inter-polar vector along Y
    dff1 = dff.copy()
    pts = list(dff['name'].unique())
    for pt in pts:
        # find all 't' where this point is defined
        #   (N.B. this is likely a subset of 't' where centrosome triple is defined)
        t_pt_defined = dff[dff['name']==pt]['t']

        # get coords for Point and 3 reference points (C3 shorthand for Cmidpoint+1)
        #   N.B. P_ ndarray order: time, XYZ
        P_original = dff[(dff['t'].isin(t_pt_defined)) & (dff['name']==pt)].loc[:, ['X', 'Y', 'Z']].to_numpy()
        C1 = dff[(dff['t'].isin(t_pt_defined)) & (dff['name']=='C1')].loc[:, ['X', 'Y', 'Z']].to_numpy()
        C2 = dff[(dff['t'].isin(t_pt_defined)) & (dff['name']=='C2')].loc[:, ['X', 'Y', 'Z']].to_numpy()
        C3 = dff[(dff['t'].isin(t_pt_defined)) & (dff['name']=='Cmidpoint+1')].loc[:, ['X', 'Y', 'Z']].to_numpy()
        nt = P_original.shape[0]

        # calculate additional points and vectors
        Cm = (C1 + C2) / 2  # C1, C2 midpoint
        Vip = C2 - C1  # C1->C2 inter-polar vector
        Vz = C3 - Cm  # Cm->C3 vector 'Vz'

        # translate all points to make original C1,C2 mid-point the new origin: P_original->P_trans
        P_trans = P_original - Cm

        # rotate points so that inter-polar vector along y
        P_trans_alignY = P_trans.copy()
        for t in range(nt):
            P_trans_alignY[t,:] = align_interpolar_to_Y(Vip[t], P_trans[t,:])

        dff1.loc[(dff1['t'].isin(t_pt_defined)) & (dff1['name']==pt), ['X', 'Y', 'Z']] = P_trans_alignY

    # step 2: align XZ component of origin-to-midpoint vector back along Z
    dff2 = dff1.copy()
    for pt in pts:
        # find all 't' where this point is defined
        #   (N.B. this is likely a subset of 't' where centrosome triple is defined)
        t_pt_defined = dff1[dff1['name']==pt]['t']

        # get coords for Point and 3 reference points (C3 shorthand for Cmidpoint+1)
        #   N.B. P_ ndarray order: time, XYZ
        P_step1 = dff1[(dff1['t'].isin(t_pt_defined)) & (dff1['name']==pt)].loc[:, ['X', 'Y', 'Z']].to_numpy()
        C1 = dff1[(dff1['t'].isin(t_pt_defined)) & (dff1['name']=='C1')].loc[:, ['X', 'Y', 'Z']].to_numpy()
        C2 = dff1[(dff1['t'].isin(t_pt_defined)) & (dff1['name']=='C2')].loc[:, ['X', 'Y', 'Z']].to_numpy()
        C3 = dff1[(dff1['t'].isin(t_pt_defined)) & (dff1['name']=='Cmidpoint+1')].loc[:, ['X', 'Y', 'Z']].to_numpy()
        nt = P_step1.shape[0]

        Vom = C3  # origin->mid-point+1 (in translated, y-aligned basis)
        VomXZ = Vom.copy()
        VomXZ[:,1] = 0  # set y-component to zero
        P_step2 = P_step1.copy()
        for t in range(nt):
            P_step2[t,:] = realign_OM_to_Z(VomXZ[t], P_step1[t,:])

        dff2.loc[(dff2['t'].isin(t_pt_defined)) & (dff2['name']==pt), ['X', 'Y', 'Z']] = P_step2


    # step 3: optionally translate along Y to make one of the poles the new origin
    #   otherwise default to midpoint as x=y=z=0
    dffp = dff2.copy()
    for pt in pts:
        # find all 't' where this point is defined
        #   (N.B. this is likely a subset of 't' where centrosome triple is defined)
        t_pt_defined = dff1[dff1['name']==pt]['t']

        # get coords for Point and 3 reference points (C3 shorthand for Cmidpoint+1)
        #   N.B. P_ ndarray order: time, XYZ
        P_step2 = dff2[(dff2['t'].isin(t_pt_defined)) & (dff2['name']==pt)].loc[:, ['X', 'Y', 'Z']].to_numpy()
        C1 = dff2[(dff2['t'].isin(t_pt_defined)) & (dff2['name']=='C1')].loc[:, ['X', 'Y', 'Z']].to_numpy()
        C2 = dff2[(dff2['t'].isin(t_pt_defined)) & (dff2['name']=='C2')].loc[:, ['X', 'Y', 'Z']].to_numpy()
        nt = P_step1.shape[0]

        P_step3 = P_step2.copy()

        if origin_point < 3:
            if origin_point == 2:
                P_step3 = P_step2 - C2
            else:
                P_step3 = P_step2 - C1
        else:
            P_step3 = P_step2

        # populate dffp with translated, rotated, re-translated point coordinates
        dffp.loc[(dffp['t'].isin(t_pt_defined)) & (dffp['name']==pt), ['X', 'Y', 'Z']] = P_step3

    return dffp


def main():
    if len(sys.argv) not in (2, 3):
        display_help()

    path = sys.argv[1]

    if len(sys.argv) == 3:
        origin_point = int(sys.argv[2])
    else:
        origin_point = DEFAULT_ORIGIN_POINT     

    if os.path.isfile(path) and path.endswith(".xlsx"):
        process_excel_file(path, origin_point)
    elif os.path.isdir(path):
        process_folder(path, origin_point)
    else:
        print("Error: The provided path is neither a valid folder nor an Excel (.xlsx) file.")
        sys.exit(1)

if __name__ == "__main__":
    main()
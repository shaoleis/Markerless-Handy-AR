//
//  myfit.cpp
//  Estimate_Homography
//
//  Created by Simon Lucey on 9/21/15.
//  Copyright (c) 2015 CMU_16432. All rights reserved.
//

#include "myfit.h"
#
// Use the Armadillo namespace
using namespace arma;

//-----------------------------------------------------------------
// Function to return the affine warp between 3D points on a plane
//
// <in>
// X = concatenated matrix of 2D projected points in the image (2xN)
// W = concatenated matrix of 3D points on the plane (3XN)
//
// <out>
// A = 2x3 matrix of affine parameters
fmat myfit_affine(fmat &X, fmat &W) {

    // Fill in the answer here.....
    fmat A; return A;
}
//-----------------------------------------------------------------
// Function to project points using the affine transform
//
// <in>
// W = concatenated matrix of 3D points on the plane (3XN)
// A = 2x3 matrix of affine parameters
//
// <out>
// X = concatenated matrix of 2D projected points in the image (2xN)
fmat myproj_affine(fmat &W, fmat &A) {

    // Fill in the answer here.....
    fmat X; return X;
}

//-----------------------------------------------------------------
// Function to return the affine warp between 3D points on a plane
//
// <in>
// X = concatenated matrix of 2D projected points in the image (2xN)
// W = concatenated matrix of 3D points on the plane (3XN)
//
// <out>
// H = 3x3 homography matrix
fmat myfit_homography(fmat &X, fmat &W) {
    
    // Fill in the answer here.....
    
    
    mat A(8,9);

    vec s;
    mat v;
    mat u;
    for (int i=0;i<4;i++)
    {
        A(2*i,0) = W(0,i);
        A(2*i,1) = W(1,i);
        A(2*i,2) = 1;
        A(2*i,3) = 0;
        A(2*i,4) = 0;
        A(2*i,5) = 0;
        A(2*i,6) = -W(0,i)*X(0,i);
        A(2*i,7) = -W(1,i)*X(0,i);
        A(2*i,8) = -X(0,i);
        
        A(2*i+1,0) = 0;
        A(2*i+1,1) = 0;
        A(2*i+1,2) = 0;
        A(2*i+1,3) = W(0,i);
        A(2*i+1,4) = W(1,i);
        A(2*i+1,5) = 1;
        A(2*i+1,6) = -W(0,i)*X(1,i);
        A(2*i+1,7) = -W(1,i)*X(1,i);
        A(2*i+1,8) = -X(1,i);
    }
    
    mat M(9,9);
    M = A.t()*A;
    
    //A.t().raw_print();
    //M.raw_print();
    svd(u, s, v, M);
    
    //eig_sym(s, u, M,"std");
    //M.raw_print();
    //u.raw_print();
    //v.raw_print();
    //eigvec.col(1).raw_print();
    fmat H(3,3);//
    H(0,0) = u(0,8);
    H(0,1) = u(1,8);
    H(0,2) = u(2,8);
    H(1,0) = u(3,8);
    H(1,1) = u(4,8);
    H(1,2) = u(5,8);
    H(2,0) = u(6,8);
    H(2,1) = u(7,8);
    H(2,2) = u(8,8);
    //H.raw_print();
    return H;
}

//-----------------------------------------------------------------
// Function to project points using the affine transform
//
// <in>
// W = concatenated matrix of 3D points on the plane (3XN)
// H = 3x3 homography matrix
//
// <out>
// X = concatenated matrix of 2D projected points in the image (2xN)
fmat myproj_homography(fmat &W, fmat &H) {
    
    int i;

    for(i=0;i<W.n_cols;i++)
    {
        W(2,i) = 1;
    }
    fmat X = H*W;
    
    for(i=0;i<W.n_cols;i++)
    {
        X(0,i) = X(0,i)/X(2,i);
        X(1,i) = X(1,i)/X(2,i);
    }
    //X.raw_print();
    return X;
}

fmat my_ransac(std::vector< cv::DMatch > matches, std::vector<cv::KeyPoint> keypts_1,
               std::vector<cv::KeyPoint> keypts_2) {

    int length = matches.size();
    arma::fmat W;
    W << 0.0 << 18.2 << 18.2 <<  0.0 << arma::endr
    << 0.0 <<  0.0 << 26.0 << 26.0 << arma::endr
    << 0.0 <<  0.0 <<  0.0 << 0.0;
    
    // Corresponding 2D projected points of the book in the image
    arma::fmat X;
    X << 483 << 1704 << 2175 <<  67 << arma::endr
    << 810 <<  781 << 2217 << 2286;
    fmat h;

    h = myfit_homography(W, X);
    //h.raw_print();

    fmat prince(3,length);
    
    for(int i=0;i<length;i++)
    {
        prince(0,i) = keypts_1[matches[i].queryIdx].pt.x;
        prince(1,i) = keypts_1[matches[i].queryIdx].pt.y;
        prince(2,i) = 1;
    }
    fmat p = myproj_homography(prince, h);
    
    std::vector< cv::DMatch > good_matches;
    for(int i =0; i<length;i++)
    {
        if(p(0,i)<18.2 && p(0,i)>0 && p(1,i) <26 && p(1,i)>0 )
        {
            good_matches.push_back(matches[i]);
        }
    }
    
    int N = good_matches.size();
    
    int iteration = 10000;
    
    fmat temp_src(3,4);
    fmat temp_dst(3,4);
    fmat pts_src(3,N);
    fmat pts_dst(3,N);
    fmat result(3,N);
    for(int j=0;j<N;j++)
    {
        
        pts_src(0,j) = keypts_1[good_matches[j].queryIdx].pt.x;
        pts_src(1,j) = keypts_1[good_matches[j].queryIdx].pt.y;
        pts_src(2,j) = 1;
        
        pts_dst(0,j) = keypts_2[good_matches[j].trainIdx].pt.x;
        pts_dst(1,j) = keypts_2[good_matches[j].trainIdx].pt.y;
        pts_dst(2,j) = 1;
    }
    fmat mean_src = mean(pts_src,1);
    fmat mean_dst = mean(pts_dst,1);

    fmat t_src(3,3);
    t_src << 1 << 0 << -mean_src(0,0) << arma::endr
    << 0.0 <<  1 << -mean_src(1,0)  << arma::endr
    << 0.0 <<  0.0 << 1;

    fmat t_dst(3,3);
    t_dst << 1 << 0 << -mean_dst(0,0) << arma::endr
    << 0.0 <<  1 << -mean_dst(1,0)  << arma::endr
    << 0.0 <<  0.0 << 1;

    fmat ts_src(3,600);
    fmat ts_dst(3,600);
    ts_src = t_src*pts_src;
    ts_dst = t_dst*pts_dst;
    
    double dist_src = 0.0;
    double dist_dst = 0.0;
    
    for(int i=0;i<N;i++)
    {
        dist_src = dist_src+sqrt(ts_src(0,i)*ts_src(0,i) + ts_src(1,i)*ts_src(1,i));
        dist_dst = dist_dst+sqrt(ts_dst(0,i)*ts_dst(0,i) + ts_dst(1,i)*ts_dst(1,i));
    }
    
    
    

    /*fmat scale_src(3,3);
    
    scale_src << sqrt(2)*N/dist_src << 0 << 0 << arma::endr
    << 0.0 <<  sqrt(2)*N/dist_src << 0 << arma::endr
    << 0.0 <<  0.0 << 1;
    
    fmat scale_dst(3,3);
    
    scale_dst << sqrt(2)*N/dist_dst << 0 << 0 << arma::endr
    << 0.0 <<  sqrt(2)*N/dist_dst << 0 << arma::endr
    << 0.0 <<  0.0 << 1;*/
    
    fmat temph;
    fmat diff(3,N);
    int inlier_num =0;
    int max_inlier = 0;
    float threshold = 0.05;
    fmat H(3,3);

    t_src = (sqrt(2)*N/dist_src)*t_src;
    t_dst = (sqrt(2)*N/dist_dst)*t_dst;
    t_src(2,2) = 1;
    t_dst(2,2) = 1;
    ts_src = t_src*pts_src;
    ts_dst = t_dst*pts_dst;
    
    for (int i = 0;i<iteration;i++)
    {
        imat r = randi(1,4,distr_param(1,N));
 
        for(int j =0;j<4;j++)
        {
            temp_src(0,j) =ts_src(0,r(j)-1);
            temp_src(1,j) =ts_src(1,r(j)-1);
            temp_src(2,j) = 1;
            temp_dst(0,j) =ts_dst(0,r(j)-1);
            temp_dst(1,j) =ts_dst(1,r(j)-1);
            temp_dst(2,j) = 1;
        }
        //temp_dst.raw_print();
        //temp_src.raw_print();
        temph = myfit_homography(temp_dst, temp_src);

        //temph.raw_print();
        result = myproj_homography(ts_src, temph);
 
        diff = result-ts_dst;
        for (int k =0;k<N;k++)
        {
            if(diff(0,k)*diff(0,k) + diff(1,k)*diff(1,k) < threshold)
                inlier_num = inlier_num+1;
        }
        if(max_inlier<inlier_num)
        {
            max_inlier = inlier_num;
            H = temph;
        }
        inlier_num = 0;
    }
    //cout << "Armadillo \\ " << max_inlier << " times faster than OpenCV!!!" << endl;
    H = inv(t_dst)*H*t_src;
    return H;
}

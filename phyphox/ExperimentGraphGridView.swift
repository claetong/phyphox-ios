//
//  ExperimentGraphGridView.swift
//  phyphox
//
//  Created by Jonas Gessner on 24.03.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

final class ExperimentGraphGridView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layer.borderColor = UIColor(white: 0.0, alpha: 0.5).CGColor
        layer.borderWidth = 1.0
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        self.init()
    }
    
    var grid: GraphGrid? {
        didSet {
            updateLineViews()
            setNeedsLayout()
        }
    }
    
    private func updateLineViews() {
        var neededViews = 0
        if grid != nil {
            if grid!.xGridLines != nil {
                neededViews += grid!.xGridLines!.count
            }
            
            if grid!.yGridLines != nil {
                neededViews += grid!.yGridLines!.count
            }
        }
        
        let delta = lineViews.count-neededViews
        
        if delta > 0 {
            var index = 0
            
            lineViews = lineViews.filter({ (view) -> Bool in
                if index < neededViews {
                    index += 1
                    return true
                }
                else {
                    view.removeFromSuperview()
                    return false
                }
            })
        }
        else if delta < 0 {
            for _ in delta..<0 {
                let view = UIView()
                view.backgroundColor = UIColor.blackColor()
                view.alpha = 0.5
                view.userInteractionEnabled = false
                
                addSubview(view)
                
                lineViews.append(view)
            }
        }
    }
    
    private var lineViews: [UIView] = []
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if grid != nil {
            var index = 0
            
            if grid!.xGridLines != nil {
                for line in grid!.xGridLines! {
                    let view = lineViews[index]
                    
                    view.frame = CGRectMake(self.bounds.size.width*line.relativeValue-0.5, 0.0, 1.0, self.bounds.size.height)
                    
                    index += 1
                }
            }
            
            if grid!.yGridLines != nil {
                for line in grid!.yGridLines! {
                    let view = lineViews[index]
                    
                    view.frame = CGRectMake(0.0, self.bounds.size.height*line.relativeValue-0.5, self.bounds.size.width, 1.0)
                    
                    index += 1
                }
            }
        }
    }
}
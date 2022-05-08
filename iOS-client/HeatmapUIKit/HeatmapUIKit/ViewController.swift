//
//  ViewController.swift
//  HeatmapUIKit
//
//  Created by Kamber Vogli on 15.03.22.
//

import UIKit
import AzureMapsControl

class ViewController: UIViewController, AzureMapDelegate {
//    func indoorManager(_ manager: IndoorManager, didSelectFacility selectedFacility: IndoorFacilitySelection, previousSelection: IndoorFacilitySelection) {
//        print("did select facility")
//    }
    
    private var azureMap: MapControl!
    private var heatmapLayers: [HeatMapLayer?]!
    private var radius = 20.0, opacity = 0.8, intensity = 1.0, weight = 1.0
    
    private var radiusLabel  = UILabel(),
                opacityLabel = UILabel(),
                intensityLabel = UILabel(),
                weightLabel    = UILabel()
    
    private var dataSource: DataSource!
    private var heatmapLayer: HeatMapLayer!
    
    private var interpolation = Interpolation()
//    private var indoorManager: IndoorManager!
    
    private var popup: Popup!
    
    func azureMap(_ map: AzureMap, didTapAt location: CLLocationCoordinate2D) {
        print("did tap at lat: \(location.latitude) , long: \(location.longitude)")
    }
    
    override func loadView() {
        super.loadView()
        azureMap = MapControl.init(frame: CGRect(x: 0, y: 0, width: 500, height: 800),
                                   options: [
                                    CameraOption.center(lat: 48.2692083204, lng: 11.6690079838),
                                    CameraOption.zoom(15),
                                    CameraOption.maxZoom(24)
                                   ])
        setupDataSource()
        
        azureMap.onReady { map in
            map.events.addDelegate(self)
            map.sources.add(self.dataSource)
            self.dataSource.add(geometry: Point(CLLocationCoordinate2D(latitude: 48.2692083204, longitude: 11.6690079838)))
            // Load a custom icon image into the image sprite of the map.
            map.images.add(UIImage(named: "wifi-black")!, withID: "cluster")
            map.images.add(UIImage(named: "wifi")!, withID: "ap")
            
            let clusterLayer = SymbolLayer(source: self.dataSource,
                                    options: [
                                        .iconImage("cluster"),
                                        .textField(from: NSExpression(forKeyPath: "point_count")),
                                        .iconSize(0.2),
                                        .textOffset(CGVector(dx: 0, dy: 0.4)),
//                                        .iconAllowOverlap(true),
//                                        .textAllowOverlap(true),
//                                        .filter(from: NSPredicate(format: "point_count != NIL"))
                                    ]
            )
            map.layers.addLayer(clusterLayer)
            
//            let apLayer = SymbolLayer(source: self.dataSource,
//                                      options: [
//                                        .iconImage("ap"),
//                                        .iconSize(0.1),
//                                        .filter(from: NSPredicate(format: "point_count = NIL"))
//                                      ])
//            map.layers.addLayer(apLayer)
            
            let popup = Popup()
            map.popups.add(popup)
            self.popup = popup
            
//            guard let indoor = try? IndoorManager(azureMap: map, options: [.tilesetID("labels")]) else { return }
//            self.indoorManager = indoor
//            self.indoorManager.addDelegate(self)
            
            //            self.useMultipleLayers(map)
            self.useSingleLayer(map)
        }
        
        self.view.addSubview(azureMap)
    }
    
    
    func azureMap(_ map: AzureMap, didTapOn features: [Feature]) {
        guard let popup = popup, let feature = features.first else {
            // Popup has been released or no features provided
            return
        }
        
        let count = dataSource.leaves(of: feature, offset: 0, limit: .max)
        print(count)
        
        // Create the custom view for the popup.
        let customView = PopupTextView()

        // Set the text to the custom view.
        let text = feature.properties["title"] as! String
        customView.setText(text)

        // Get the position of the tapped feature.
        let position = Math.positions(from: feature).first!

        // Set the options on the popup.
        popup.setOptions([
            // Set the popups position.
            .position(position),

            // Set the anchor point of the popup content.
            .anchor(.bottom),

            // Set the content of the popup.
            .content(customView)

            // Optionally, hide the close button of the popup.
            // .closeButton(false)

            // Optionally offset the popup by a specified number of points.
            // .pointOffset(CGPoint(x: 10, y: 10))
        ])

        // Open the popup.
        popup.open()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Add slider controls after loading the view.
        addControl(title: "Radius",  valueLabel: &radiusLabel,  distFromTop: 50,  min: 1, max: 50, #selector(updateRadius(_:)))
        addControl(title: "Opacity", valueLabel: &opacityLabel, distFromTop: 100, min: 0, max: 1,  #selector(updateOpacity(_:)))
        addControl(title: "Intencity", valueLabel: &intensityLabel, distFromTop: 150, min: 0, max: 5,  #selector(updateIntensity(_:)))
        addControl(title: "Weight", valueLabel: &weightLabel, distFromTop: 200, min: 0, max: 5,  #selector(updateWeight(_:)))
        addControl(title: "Weight-S", valueLabel: &weightLabel, distFromTop: 250, min: 0, max: 1,  #selector(updateWeightSmall(_:)))
    }
    
    private func setupDataSource() {
        dataSource = DataSource()
        let locations = readCoordsFromJSON(file: "accessPoints")
//        let pointCollection = PointCollection(locations)
//        dataSource.add(geometry: pointCollection)
        var id = 1
        for location in locations {
            let feature = Feature(Point(location))
            
            id += 1
            // Add a property to the feature.
            feature.addProperty("title", value: "Access Point \(id)")
            dataSource.add(feature: feature)
        }
    }
    
    private func readCoordsFromJSON(file filename: String) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        do {
            if let path = Bundle.main.url(forResource: filename, withExtension: "json") {
                let data = try Data(contentsOf: path)
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                if let object = json as? [[String: Any]] {
                    for item in object {
                        let lat  = item["Latitude"] as? Double ?? 0.0
                        let long = item["Longitude"] as? Double ?? 0.0
                        let coord = CLLocationCoordinate2D(latitude: lat, longitude: long)
                        coordinates.append(coord)
                    }
                }
            }
        } catch {
            print("Could not read json file!")
            return coordinates
        }
        return coordinates
    }
}

extension ViewController {
    
    private func useMultipleLayers(_ map: AzureMap) {
        //setup heatmap layers and add them all to map
        heatmapLayers = [HeatMapLayer?](repeating: nil, count: 46)
        var index = 0
        for i in stride(from: 1, to: 23, by: 0.5) {
            let options: [HeatMapLayerOption]
            
            let newRadius = lagrange(points: interpolation.radiusPoints, x: i)
            let newOpacity = lagrange(points: interpolation.opacityPoints, x: i)
            let newWeight = lagrange(points: interpolation.weightPoints, x: i)
            
            options = [
                .heatmapRadius(newRadius),
                .heatmapOpacity(newOpacity),
                .minZoom(Double(i) - 0.1),
                .maxZoom(Double(i) + 0.6),
                .heatmapWeight(newWeight)
            ]
            
            let heatmapLayer = HeatMapLayer(
                source: dataSource,
                options: options
            )
            heatmapLayers[index] = heatmapLayer
            index += 1
            map.layers.insertLayer(heatmapLayer, below: "labels")
        }
    }
    
    private func useSingleLayer(_ map: AzureMap) {
        heatmapLayer = HeatMapLayer(
            source: dataSource,
            options: [
                .heatmapRadius(
                    from: NSExpression(
                        forAZMInterpolating: .zoomLevelAZMVariable,
                        curveType: .exponential,
                        parameters: NSExpression(forConstantValue: 7),
                        stops: NSExpression(forConstantValue: [
                            // For zoom level 1 set the radius to 2 points.
                            1: 2,
                            15: 15,
                            16: 30,
                            17: 40,
                            18: 45,
                            19: 50,
                            23: 1000
                        ])
                    )
                ),
                .heatmapOpacity(0.8),
                .minZoom(1.0),
                .maxZoom(24)
            ]
        )
        map.layers.insertLayer(heatmapLayer, below: "labels")
    }
    
    private func addControl(title: String, valueLabel: inout UILabel, distFromTop: Int, min: Float, max: Float ,_ objcFunc: Selector) {
        let titleLabel = UILabel(frame: CGRect(x: 510, y: distFromTop, width: 80, height: 20))
        titleLabel.text = title
        valueLabel = UILabel(frame: CGRect(x: 850, y: distFromTop, width: 100, height: 20))
        valueLabel.text = "0.0"
        addUISlider(xOrig: 600, yOrig: distFromTop, width: 200, height: 20, minVal: min, maxVal: max, objcFunc: objcFunc)
        view.addSubview(titleLabel)
        view.addSubview(valueLabel)
    }
    
    private func addUISlider(xOrig: Int, yOrig: Int, width: Int, height: Int, minVal: Float, maxVal: Float, objcFunc: Selector) {
        let slider = UISlider(frame: CGRect(x: xOrig, y: yOrig, width: width, height: height))
        slider.minimumValue = minVal
        slider.maximumValue = maxVal
        slider.isContinuous = true
        slider.addTarget(self, action: objcFunc, for: .valueChanged)
        view.addSubview(slider)
    }
    
    @objc
    func updateRadius(_ sender: UISlider!) {
        let step:Float = 0.05
        let stepValue = round(sender.value / step) * step
        sender.value = stepValue
        radius = Double(stepValue)
        radiusLabel.text = String(radius)
        heatmapLayer.setOptions([.heatmapRadius(radius)])
    }
    
    @objc
    func updateOpacity(_ sender: UISlider!) {
        let step:Float = 0.01
        let stepValue = round(sender.value / step) * step
        sender.value = stepValue
        opacity = Double(stepValue)
        opacityLabel.text = String(opacity)
        heatmapLayer.setOptions([.heatmapOpacity(opacity)])
    }
    
    @objc
    func updateIntensity(_ sender: UISlider!) {
        let step:Float = 0.01
        let stepValue = round(sender.value / step) * step
        sender.value = stepValue
        intensity = Double(stepValue)
        intensityLabel.text = String(intensity)
        heatmapLayer.setOptions([.heatmapIntensity(intensity)])
    }
    
    @objc
    func updateWeight(_ sender: UISlider!) {
        let step:Float = 0.01
        let stepValue = round(sender.value / step) * step
        sender.value = stepValue
        weight = Double(stepValue)
        weightLabel.text = String(weight)
        heatmapLayer.setOptions([.heatmapWeight(weight)])
    }
    
    @objc
    func updateWeightSmall(_ sender: UISlider!) {
        let step:Float = 0.005
        let stepValue = round(sender.value / step) * step
        sender.value = stepValue
        weight = Double(stepValue)
        weightLabel.text = String(weight)
        heatmapLayer.setOptions([.heatmapWeight(weight)])
    }
}
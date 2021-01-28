//
//  Models.swift
//  First Attempt
//
//  Created by Daniel Aragon on 8/16/20.
//  Copyright © 2020 Daniel Aragon. All rights reserved.
//

import Foundation
import ARKit
import RealityKit
import Combine

class TowerBundle {
    var model: ModelEntity
    var type: TowerType
    var lvl: TowerLevel
    var accessory: Entity
    var enemiesIds: [UInt64]
    var collisionSubs: [Cancellable]
    init(model: ModelEntity, type: TowerType, lvl: TowerLevel = .lvl1, accessory: Entity, collisionSubs: [Cancellable]) {
        self.model = model
        self.type = type
        self.lvl = lvl
        self.accessory = accessory
        self.enemiesIds = []
        self.collisionSubs = collisionSubs
    }
    
    func fireBullet(towerId: UInt64, creepModel: ModelEntity, anchor: AnchorEntity, placingPosition: SIMD3<Float>) {
        let capacity = min(enemiesIds.count, type.capacity(lvl: lvl))
        enemiesIds[0..<capacity].forEach { id in
            guard id == creepModel.id else { return }
            let bullet = mapTemplates[ModelType.bullet.key]!.embeddedModel(at: placingPosition)
            bullet.model.transform.translation.y += 0.015
            anchor.addChild(bullet.model)
            var bulletTransform = bullet.model.transform
            bulletTransform.translation = creepModel.position
            //            bullet.model.orientation = orientato(to: creepModel)
            let animation = bullet.model.move(to: bulletTransform, relativeTo: bullet.model.anchor, duration: 0.2, timingFunction: .linear)
            let subscription = arView.scene.publisher(for: AnimationEvents.PlaybackCompleted.self)
                .filter { $0.playbackController == animation }
                .sink( receiveValue: { event in
                    self.bullets.forEach { bulletId, bulletBundle in
                        if bulletBundle.animation.isComplete {
                            bulletBundle.subscription?.cancel()
                            self.bullets.removeValue(forKey: bulletId)
                        }
                    }
                    self.bullets[bullet.model.id]?.model.removeFromParent()
//                    self.damageCreep(creepModel: creepModel, towerId: towerId, attack: towerType.attack(lvl: towerLvl))
                })
            self.bullets[bullet.model.id] = BulletBundle(model: bullet.model, animation: animation,subscription: subscription)
        }
    }
    
    func damageCreep(creepModel: ModelEntity, towerId: UInt64, attack: Float) {
        guard let creepBundle = creeps[creepModel.id], let (childIndex, child) = creepModel.children.enumerated().first(where: { $1.id == creeps[creepModel.id]?.unit.hpBarId }) else { return }
        creeps[creepModel.id]?.unit.hp -= attack
        if creepBundle.unit.hp < 0 {
            coins += creepBundle.type.reward
            towers[towerId]?.enemiesIds.removeAll(where: { id in id == creepModel.id })
            troops[towerId]?.enemiesIds.removeAll(where: { id in id == creepModel.id })
            creepModel.removeFromParent()
            creeps.removeValue(forKey: creepModel.id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.checkMissionCompleted()
            }
        }
        let hpPercentage = creepBundle.unit.hp / creepBundle.unit.maxHP
        let hpBar = mapTemplates[Lifepoints.status(hp: hpPercentage).key]!.clone(recursive: true)
        hpBar.scale = [hpPercentage, 1.0, 1.0]
        creepModel.children[childIndex] = hpBar
        hpBar.position = child.position
        child.removeFromParent()
        creeps[creepModel.id]?.unit.hpBarId = hpBar.id
    }
    
}

class SpawnBundle {
    var model: ModelEntity
    var position: Position
    var map: Int
    init(model: ModelEntity, position: Position, map: Int) {
        self.model = model
        self.position = position
        self.map = map
    }
}

class PlacingBundle {
    var model: ModelEntity
    var position: Position
    var towerId: UInt64?
    init(model: ModelEntity, position: Position) {
        self.model = model
        self.position = position
    }
}

class UnitBundle {
    var hpBarId: UInt64
    var hp: Float
    var maxHP: Float
    init(hpBarId: UInt64, hp: Float, maxHP: Float) {
        self.hpBarId = hpBarId
        self.hp = hp
        self.maxHP = maxHP
    }
}

class CreepBundle: CanDamage {
    var unit: UnitBundle
    var type: CreepType
    var animation: AnimationPlaybackController?
    var subscription: Cancellable?
    init(unit: UnitBundle, type: CreepType) {
        self.unit = unit
        self.type = type
    }
    func damageTroop(troopModel: ModelEntity, creepId: UInt64, attack: Float) {
        guard let troopBundle = troops[troopModel.id], let (childIndex, child) = troopModel.children.enumerated().first(where: { $1.id == troops[troopModel.id]?.unit.hpBarId }) else { return }
        troops[troopModel.id]?.unit.hp -= attack
        if troopBundle.unit.hp < 0 {
            creeps[creepId]?.animation?.resume()
            troopModel.removeFromParent()
            troops[troopModel.id]?.enemiesIds.removeAll()
            troops.removeValue(forKey: troopModel.id)
        }
        let hpPercentage = troopBundle.unit.hp / troopBundle.unit.maxHP
        let hpBar = mapTemplates[Lifepoints.status(hp: hpPercentage).key]!.clone(recursive: true)
        hpBar.scale = [hpPercentage, 1.0, 1.0]
        troopModel.children[childIndex] = hpBar
        hpBar.position = child.position
        child.removeFromParent()
        troops[troopModel.id]?.unit.hpBarId = hpBar.id
    }
}

class TroopBundle: CanDamage {
    var unit: UnitBundle
    var towerId: UInt64
    var enemiesIds: [UInt64]
    init(unit: UnitBundle, towerId: UInt64) {
        self.unit = unit
        self.towerId = towerId
        self.enemiesIds = []
    }
    func damageCreep(creepModel: ModelEntity, towerId: UInt64, attack: Float) {
        guard let creepBundle = creeps[creepModel.id], let (childIndex, child) = creepModel.children.enumerated().first(where: { $1.id == creeps[creepModel.id]?.unit.hpBarId }) else { return }
        creeps[creepModel.id]?.unit.hp -= attack
        if creepBundle.unit.hp < 0 {
            coins += creepBundle.type.reward
            towers[towerId]?.enemiesIds.removeAll(where: { id in id == creepModel.id })
            troops[towerId]?.enemiesIds.removeAll(where: { id in id == creepModel.id })
            creepModel.removeFromParent()
            creeps.removeValue(forKey: creepModel.id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.checkMissionCompleted()
            }
        }
        let hpPercentage = creepBundle.unit.hp / creepBundle.unit.maxHP
        let hpBar = mapTemplates[Lifepoints.status(hp: hpPercentage).key]!.clone(recursive: true)
        hpBar.scale = [hpPercentage, 1.0, 1.0]
        creepModel.children[childIndex] = hpBar
        hpBar.position = child.position
        child.removeFromParent()
        creeps[creepModel.id]?.unit.hpBarId = hpBar.id
    }
}

class BulletBundle {
    var model: ModelEntity
    var animation: AnimationPlaybackController
    var subscription: Cancellable?
    init (model: ModelEntity, animation: AnimationPlaybackController, subscription: Cancellable) {
        self.model = model
        self.animation = animation
        self.subscription = subscription
    }
}

DROP TABLE IF EXISTS `asset_definition`;
CREATE TABLE `asset_definition` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '资产定义编号',
  `code` varchar(64) NOT NULL COMMENT '资产编码',
  `name` varchar(128) NOT NULL COMMENT '资产名称',
  `asset_type` tinyint NOT NULL COMMENT '资产类型：1报告 2课程 3咨询 99其他',
  `fulfillment_type` tinyint NOT NULL COMMENT '履约类型：1QUOTA次数型 2ACCESS访问型 3APPOINTMENT预约型',
  `unit_type` tinyint NOT NULL COMMENT '单位类型：1次 2份 3天 4月 5席位',
  `expire_rule_type` tinyint NOT NULL DEFAULT 1 COMMENT '过期规则：1永久 2固定时间 3领取后N天',
  `fixed_expire_time` datetime DEFAULT NULL COMMENT '固定过期时间',
  `expire_days` int DEFAULT NULL COMMENT '领取后有效天数',
  `support_refund` bit(1) NOT NULL DEFAULT b'1' COMMENT '是否支持退款回退',
  `support_transfer` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否支持转移',
  `status` tinyint NOT NULL DEFAULT 1 COMMENT '状态：1启用 0停用',
  `remark` varchar(255) DEFAULT NULL COMMENT '备注',

  `creator` varchar(64) DEFAULT '' COMMENT '创建者',
  `createtime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater` varchar(64) DEFAULT '' COMMENT '更新者',
  `updatetime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenantid` bigint NOT NULL DEFAULT 0 COMMENT '租户编号',

  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_code` (`code`) USING BTREE,
  KEY `idx_asset_type` (`asset_type`) USING BTREE,
  KEY `idx_fulfillment_type` (`fulfillment_type`) USING BTREE,
  KEY `idx_status` (`status`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='资产定义表';

DROP TABLE IF EXISTS `asset_sku_grant_rule`;
CREATE TABLE `asset_sku_grant_rule` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT 'SKU资产发放规则编号',
  `spu_id` bigint NOT NULL COMMENT '商品SPU ID',
  `sku_id` bigint NOT NULL COMMENT '商品SKU ID',
  `asset_id` bigint NOT NULL COMMENT '资产定义ID',

  `asset_code_snapshot` varchar(64) NOT NULL COMMENT '资产编码快照',
  `asset_name_snapshot` varchar(128) NOT NULL COMMENT '资产名称快照',
  `fulfillment_type` tinyint NOT NULL COMMENT '履约类型快照：1QUOTA 2ACCESS 3APPOINTMENT',
  `unit_type` tinyint NOT NULL COMMENT '单位类型快照：1次 2份 3天 4月 5席位',

  `grant_mode` tinyint NOT NULL COMMENT '发放模式：1固定数量 2固定天数 3永久访问',
  `grant_quantity` int NOT NULL DEFAULT 0 COMMENT '发放数量；次数型/预约型使用',
  `grant_days` int NOT NULL DEFAULT 0 COMMENT '发放天数；访问型使用',
  `permanent` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否永久有效',

  `effective_delay_days` int NOT NULL DEFAULT 0 COMMENT '生效延迟天数',
  `expire_rule_type` tinyint NOT NULL DEFAULT 0 COMMENT '过期规则：0跟随资产定义 1永久 2固定时间 3领取后N天',
  `fixed_expire_time` datetime DEFAULT NULL COMMENT '固定过期时间',
  `expire_days` int DEFAULT NULL COMMENT '领取后有效天数',

  `sort` int NOT NULL DEFAULT 0 COMMENT '排序',
  `status` tinyint NOT NULL DEFAULT 1 COMMENT '状态：1启用 0停用',
  `remark` varchar(255) DEFAULT NULL COMMENT '备注',

  `creator` varchar(64) DEFAULT '' COMMENT '创建者',
  `createtime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater` varchar(64) DEFAULT '' COMMENT '更新者',
  `updatetime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenantid` bigint NOT NULL DEFAULT 0 COMMENT '租户编号',

  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_sku_asset` (`sku_id`, `asset_id`, `deleted`) USING BTREE,
  KEY `idx_spu_id` (`spu_id`) USING BTREE,
  KEY `idx_asset_id` (`asset_id`) USING BTREE,
  KEY `idx_status` (`status`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='SKU资产发放规则表';

DROP TABLE IF EXISTS `asset_user_account`;
CREATE TABLE `asset_user_account` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '用户资产账户编号',
  `user_id` bigint NOT NULL COMMENT '用户编号',
  `asset_id` bigint NOT NULL COMMENT '资产定义ID',

  `asset_code_snapshot` varchar(64) NOT NULL COMMENT '资产编码快照',
  `asset_name_snapshot` varchar(128) NOT NULL COMMENT '资产名称快照',
  `asset_type` tinyint NOT NULL COMMENT '资产类型快照：1报告 2课程 3咨询 99其他',
  `fulfillment_type` tinyint NOT NULL COMMENT '履约类型快照：1QUOTA 2ACCESS 3APPOINTMENT',
  `unit_type` tinyint NOT NULL COMMENT '单位类型快照：1次 2份 3天 4月 5席位',

  `total_quantity` int NOT NULL DEFAULT 0 COMMENT '累计发放数量',
  `used_quantity` int NOT NULL DEFAULT 0 COMMENT '累计已使用数量',
  `refund_quantity` int NOT NULL DEFAULT 0 COMMENT '累计退款回退数量',
  `adjust_quantity` int NOT NULL DEFAULT 0 COMMENT '累计人工调整数量',
  `remain_quantity` int NOT NULL DEFAULT 0 COMMENT '当前剩余数量',
  `freeze_quantity` int NOT NULL DEFAULT 0 COMMENT '冻结数量',

  `status` tinyint NOT NULL DEFAULT 1 COMMENT '状态：1正常 2冻结 3失效 4用尽',
  `effective_time` datetime DEFAULT NULL COMMENT '生效时间',
  `expire_time` datetime DEFAULT NULL COMMENT '过期时间',
  `last_grant_time` datetime DEFAULT NULL COMMENT '最后发放时间',
  `last_use_time` datetime DEFAULT NULL COMMENT '最后使用时间',
  `version` int NOT NULL DEFAULT 0 COMMENT '乐观锁版本号',
  `remark` varchar(255) DEFAULT NULL COMMENT '备注',

  `creator` varchar(64) DEFAULT '' COMMENT '创建者',
  `createtime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater` varchar(64) DEFAULT '' COMMENT '更新者',
  `updatetime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenantid` bigint NOT NULL DEFAULT 0 COMMENT '租户编号',

  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_user_asset` (`user_id`, `asset_id`, `deleted`) USING BTREE,
  KEY `idx_asset_id` (`asset_id`) USING BTREE,
  KEY `idx_user_status` (`user_id`, `status`) USING BTREE,
  KEY `idx_expire_time` (`expire_time`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户资产账户表';


DROP TABLE IF EXISTS `asset_user_account_source`;
CREATE TABLE `asset_user_account_source` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '用户资产来源编号',
  `account_id` bigint NOT NULL COMMENT '用户资产账户ID',
  `user_id` bigint NOT NULL COMMENT '用户编号',
  `asset_id` bigint NOT NULL COMMENT '资产定义ID',

  `source_type` tinyint NOT NULL COMMENT '来源类型：1订单购买 2活动赠送 3后台赠送 4退款回退 5补发',
  `source_id` bigint DEFAULT NULL COMMENT '来源业务ID',
  `source_item_id` bigint DEFAULT NULL COMMENT '来源业务明细ID',
  `source_no` varchar(64) DEFAULT NULL COMMENT '来源单号',

  `order_id` bigint DEFAULT NULL COMMENT '订单ID',
  `order_item_id` bigint DEFAULT NULL COMMENT '订单项ID',
  `spu_id` bigint DEFAULT NULL COMMENT '商品SPU ID',
  `sku_id` bigint DEFAULT NULL COMMENT '商品SKU ID',

  `grant_mode` tinyint NOT NULL COMMENT '发放模式：1固定数量 2固定天数 3永久访问',
  `grant_quantity` int NOT NULL DEFAULT 0 COMMENT '本来源发放数量',
  `used_quantity` int NOT NULL DEFAULT 0 COMMENT '本来源已使用数量',
  `remain_quantity` int NOT NULL DEFAULT 0 COMMENT '本来源剩余数量',
  `grant_days` int NOT NULL DEFAULT 0 COMMENT '本来源发放天数',
  `permanent` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否永久有效',

  `effective_time` datetime DEFAULT NULL COMMENT '生效时间',
  `expire_time` datetime DEFAULT NULL COMMENT '过期时间',
  `status` tinyint NOT NULL DEFAULT 1 COMMENT '状态：1正常 2已用尽 3已退完 4已失效',
  `remark` varchar(255) DEFAULT NULL COMMENT '备注',

  `creator` varchar(64) DEFAULT '' COMMENT '创建者',
  `createtime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater` varchar(64) DEFAULT '' COMMENT '更新者',
  `updatetime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenantid` bigint NOT NULL DEFAULT 0 COMMENT '租户编号',

  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_account_id` (`account_id`) USING BTREE,
  KEY `idx_order_item_id` (`order_item_id`) USING BTREE,
  KEY `idx_user_asset` (`user_id`, `asset_id`) USING BTREE,
  KEY `idx_source` (`source_type`, `source_id`) USING BTREE,
  KEY `idx_expire_time` (`expire_time`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户资产来源表';

DROP TABLE IF EXISTS `asset_user_account_log`;
CREATE TABLE `asset_user_account_log` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '用户资产账户流水编号',
  `account_id` bigint NOT NULL COMMENT '用户资产账户ID',
  `user_id` bigint NOT NULL COMMENT '用户编号',
  `asset_id` bigint NOT NULL COMMENT '资产定义ID',
  `source_id` bigint DEFAULT NULL COMMENT '资产来源ID',

  `change_no` varchar(64) NOT NULL COMMENT '变动流水号',
  `change_type` tinyint NOT NULL COMMENT '变动类型：1发放 2扣减 3退款回退 4后台增加 5后台扣减 6过期 7冻结 8解冻 9激活',
  `change_quantity` int NOT NULL COMMENT '本次变动数量，增加为正，扣减为负',
  `before_quantity` int NOT NULL COMMENT '变动前剩余数量',
  `after_quantity` int NOT NULL COMMENT '变动后剩余数量',

  `biz_type` tinyint NOT NULL COMMENT '业务类型：1订单 2订单项 3售后 4报告任务 5课程开通 6咨询预约 7后台',
  `biz_id` bigint DEFAULT NULL COMMENT '业务ID',
  `biz_item_id` bigint DEFAULT NULL COMMENT '业务明细ID',
  `biz_no` varchar(64) DEFAULT NULL COMMENT '业务单号',

  `operator_user_id` bigint DEFAULT NULL COMMENT '操作人ID',
  `operator_user_type` tinyint DEFAULT NULL COMMENT '操作人类型',
  `remark` varchar(255) DEFAULT NULL COMMENT '备注',
  `operate_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '操作时间',

  `creator` varchar(64) DEFAULT '' COMMENT '创建者',
  `createtime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater` varchar(64) DEFAULT '' COMMENT '更新者',
  `updatetime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenantid` bigint NOT NULL DEFAULT 0 COMMENT '租户编号',

  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_change_no` (`change_no`) USING BTREE,
  KEY `idx_account_id` (`account_id`) USING BTREE,
  KEY `idx_user_time` (`user_id`, `operate_time`) USING BTREE,
  KEY `idx_biz` (`biz_type`, `biz_id`) USING BTREE,
  KEY `idx_asset_id` (`asset_id`) USING BTREE,
  KEY `idx_source_id` (`source_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户资产账户流水表';


DROP TABLE IF EXISTS `asset_usage_record`;

CREATE TABLE `asset_usage_record` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '资产使用记录编号',
  `account_id` bigint NOT NULL COMMENT '用户资产账户ID',
  `source_id` bigint DEFAULT NULL COMMENT '资产来源ID',
  `user_id` bigint NOT NULL COMMENT '用户编号',
  `asset_id` bigint NOT NULL COMMENT '资产定义ID',

  `usage_no` varchar(64) NOT NULL COMMENT '使用流水号',
  `usage_type` tinyint NOT NULL COMMENT '使用类型：1消费 2激活 3预约 4核销 5取消 6回退',
  `consume_quantity` int NOT NULL DEFAULT 0 COMMENT '本次消耗数量',
  `biz_type` tinyint NOT NULL COMMENT '业务类型：1报告任务 2课程开通 3课程学习 4咨询预约 5后台',
  `biz_id` bigint DEFAULT NULL COMMENT '业务ID',
  `biz_no` varchar(64) DEFAULT NULL COMMENT '业务单号',

  `status` tinyint NOT NULL DEFAULT 1 COMMENT '状态：1待处理 2处理中 3成功 4取消 5失败',
  `scheduled_time` datetime DEFAULT NULL COMMENT '预约/计划时间',
  `used_time` datetime DEFAULT NULL COMMENT '实际使用时间',
  `finish_time` datetime DEFAULT NULL COMMENT '完成时间',
  `remark` varchar(255) DEFAULT NULL COMMENT '备注',

  `creator` varchar(64) DEFAULT '' COMMENT '创建者',
  `createtime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updater` varchar(64) DEFAULT '' COMMENT '更新者',
  `updatetime` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` bit(1) NOT NULL DEFAULT b'0' COMMENT '是否删除',
  `tenantid` bigint NOT NULL DEFAULT 0 COMMENT '租户编号',

  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_usage_no` (`usage_no`) USING BTREE,
  KEY `idx_account_id` (`account_id`) USING BTREE,
  KEY `idx_user_asset` (`user_id`, `asset_id`) USING BTREE,
  KEY `idx_biz` (`biz_type`, `biz_id`) USING BTREE,
  KEY `idx_status` (`status`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='资产使用记录表';

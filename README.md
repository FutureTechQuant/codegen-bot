# future-codegen-bot
代码生成

## 多模块生成

`tools/codegen/run.sh` 支持两种模式：

### 单模块模式

```bash
CODEGEN_MODULE_NAME=ticket \
CODEGEN_TABLE_PREFIX=ticket_ \
bash tools/codegen/run.sh
```

### 多模块模式

通过 `CODEGEN_MODULES` 一次生成多个模块：

```bash
CODEGEN_MODULES="ticket:ticket_,map:map_,ugc:ugc_,tourism:tourism_" \
bash tools/codegen/run.sh
```

格式说明：

- `module:prefix_`：推荐写法，例如 `ticket:ticket_`
- `module=prefix_`：兼容写法，例如 `ticket=ticket_`
- `module`：简写，自动使用 `module_` 作为表前缀

脚本会：

1. 重建数据库并导入 ruoyi-vue-pro 基础 SQL。
2. 导入 `sql/schema/*.sql` 下的全部业务 SQL。
3. 按模块前缀逐个运行 ruoyi 代码生成。
4. 将所有模块输出到同一个 `out/generated` 目录。
5. 最后统一生成 app controller，并由发布脚本同步到目标仓库。

如果没有设置 `CODEGEN_MODULES`、`CODEGEN_MODULE_NAME`、`CODEGEN_TABLE_PREFIX`，脚本会根据新增业务表的第一个下划线前缀自动推断模块。例如：

- `ticket_product` -> `ticket:ticket_`
- `map_poi` -> `map:map_`
- `ugc_post` -> `ugc:ugc_`

## 注意事项

- 多模块生成时，所有模块 SQL 可以放在多个 `sql/schema/*.sql` 文件中。
- 建议每个模块使用稳定表前缀，例如 `ticket_`、`map_`、`tourism_`。
- `publish.sh` 会操作 GitHub 仓库，正式使用前请确认不会误删已有仓库。
- 生成的 app controller 需要人工 review，避免把管理端写接口暴露给游客端。

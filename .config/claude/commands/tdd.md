# TDD

Adopt a rigorous test-driven development (TDD) approach and implement comprehensive task management and quality assurance. All changes must be thoroughly tested, properly documented, and committed at the appropriate granularity. 

## Core Development Principles

### 1. **Mandatory TDD Cycle**

**CRITICAL**: Always follow the Red-Green-Refactor cycle explicitly.

#### Red Phase

1. **Write failing tests first** - Never write implementation code without a failing test
2. **Commit with explicit phase marking**: 
   ```
   test: Add failing test for [feature] (Red phase)
   
   [Optional: Explanation of expected failure]
   
   ```
3. **Write empty or dummy implementation**
4. **Verify test fails**
5. **Document expected failure** in commit message if helpful

#### Green Phase

1. **Implement minimal code** to make tests pass
2. **Commit with explicit phase marking**:
   ```
   feat: Implement [feature] (Green phase)
   
   [Optional: Brief implementation notes]
   ```
3. **Verify tests pass**
4. **Add more tests**
3. **Verify tests pass**
6. **Temporary/dummy implementations are acceptable** for Green phase

#### Refactor Phase (when needed)

1. **Improve code quality** while maintaining test coverage
2. **Commit refactoring separately**:
   ```
   refactor: [improvement description]
   
   [Optional: Brief refactoring notes]
   ```
3. **Always run full test suite** after refactoring

### 2. **Parameterized Testing Best Practices**

When converting multiple similar tests to parameterized tests:

1. **Use test.each() or it.each()** for test cases that share the same logic but differ in input/expected values
2. **Include expected values in the parameter array** - Don't rely on calculated expected values that could mask implementation bugs
3. **Vary test inputs meaningfully** - Use different dates, edge cases, and boundary values to ensure the implementation responds correctly to input changes
4. **Structure parameter arrays clearly**:
   ```javascript
   it.each([
     [input1, input2, expected, description],
     [input1, input2, expected, description],
   ])("test name %s", (input1, input2, expected, description) => {
     // test implementation
   })
   ```
5. **Avoid static expected values** - Each test case should have its own expected value to verify the function actually processes inputs dynamically

Example of good parameterized test:
```javascript
it.each([
  ["2025-01-15T12:00:00Z", "invalid-date", "2025-01-14T12:00:00Z", "invalid date"],
  ["2025-02-20T09:00:00Z", "", "2025-02-19T09:00:00Z", "empty string"],
  ["2025-03-01T00:00:00Z", undefined, "2025-02-28T00:00:00Z", "missing parameter"],
])("should return previous day when date parameter is %s", (nowStr, dateValue, expectedStr, _description) => {
  const now = new Date(nowStr)
  const result = someFunction({ now }, dateValue)
  expect(result).toEqual(new Date(expectedStr))
})
```

# Web Forntend Testing Strategy

## テスト戦略の概要

Kent C. Dodds が提唱する Testing Trophyアプローチに基づく実践的なハイブリッド戦略を採用します。

その上で単体テストはビジネスロジック、E2E テストはクリティカルパスのテストに限り、基本は統合テストをメインとした TDD を行ないます。

これは、自作自演、あるいは壊れやすいテストを避けるためのアプローチです。

## プロジェクトセットアップ

既にテストツールがセットアップされていない場合は、セットアップしてください：

- テストランナー: Vitest + Vitest BrowserMode
- 統合テスト: React Testing Library
- E2Eテスト: Playwright
- APIモック: MSW (Mock Service Worker)

## テストファイルの命名規則

ー 単体テスト ... テスト対象のファイルと同じディレクトリに {filename}.test.ts を置く
- 統合テスト ... tests/feature.ix-test.ts
- E2Eテスト ... tests/feature.e2e-test.ts

## テスト実装のガイドライン

### 統合テスト（優先度: 高）

React Testing Libraryを使用して、以下のパターンでコンポーネントテストを実装：

```typescript
// 良い例：ユーザー視点のテスト
test('商品をカートに追加できる', async () => {
  const user = userEvent.setup();
  render(<ProductCard product={mockProduct} />);
  
  const addButton = screen.getByRole('button', { name: /カートに追加/i });
  await user.click(addButton);
  
  expect(await screen.findByText('カートに追加しました')).toBeInTheDocument();
});

// 避けるべき例：実装詳細のテスト
// getByClassName, getByTestId の使用は避ける
```

### E2Eテスト（優先度: クリティカルパスのみ）

Playwrightで以下のシナリオのみを実装：

1. **認証フロー**: サインアップ → ログイン → ログアウト
2. **購入フロー**: 商品検索 → カート追加 → 決済完了
3. **コア機能**: アプリケーションの主要価値を提供する1-2個の機能

```typescript
// e2e/purchase-flow.spec.ts
test('ユーザーが商品を購入できる', async ({ page }) => {
  await page.goto('/');
  
  // ログイン
  await page.getByRole('link', { name: 'ログイン' }).click();
  await page.getByLabel('メールアドレス').fill('test@example.com');
  await page.getByLabel('パスワード').fill('password');
  await page.getByRole('button', { name: 'ログイン' }).click();
  
  // 商品選択と購入
  await page.getByRole('link', { name: '商品一覧' }).click();
  await page.getByText('商品A').click();
  await page.getByRole('button', { name: 'カートに追加' }).click();
  
  // 自動待機を活用
  await expect(page.getByText('カートに追加しました')).toBeVisible();
});
```

## パフォーマンス最適化

- **並列実行**: Vitestの並列実行を有効化
- **テストの分離**: E2Eテストは別のジョブで実行
- **選択的実行**: 変更されたファイルに関連するテストのみ実行

## 注意事項

1. **過度なテストを避ける**: 完璧を求めず、ROIの高いテストに集中
2. **実装詳細をテストしない**: ユーザー視点でのテストを心がける
3. **テストの可読性を重視**: テストはドキュメントとしても機能する
4. **継続的な改善**: 一度に完璧を目指さず、段階的に改善

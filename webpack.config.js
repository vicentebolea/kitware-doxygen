const path = require("path");
const webpack = require("webpack");

const project  = process.env.PROJECT    || "project";
const docsBase  = process.env.DOCS_BASE  || (project + "-docs");
const outputDir = process.env.OUTPUT_DIR
  ? path.resolve(process.env.OUTPUT_DIR)
  : path.resolve(__dirname, "Dist");
const entry = path.resolve(__dirname, "Src", "selector.js");

module.exports = {
  entry,
  output: {
    path: outputDir,
    filename: project + "-version.js"
  },
  plugins: [
    new webpack.DefinePlugin({
      __DOCS_BASE__: JSON.stringify(docsBase)
    })
  ],
  module: {
    rules: [
      {
        test: entry,
        loader: "expose-loader",
        options: { exposes: "KWDocs" }
      },
      {
        test: /\.js$/,
        use: [{
          loader: "babel-loader",
          options: { presets: ["@babel/preset-env"] }
        }]
      },
      {
        test: /\.css$/,
        use: [{ loader: "style-loader" }, { loader: "css-loader" }]
      },
      {
        test: /\.(png|jpg|gif)$/,
        type: "asset",
        parser: { dataUrlCondition: { maxSize: 60000 } }
      }
    ]
  }
};

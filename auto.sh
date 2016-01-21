jekyll build

git add .
git commit -m 'update'
git push -u origin master &

cp _site/* ../qwert42.github.io/ -r

cd ../qwert42.github.io
git add .
git commit -m 'update'
git push -u origin master &



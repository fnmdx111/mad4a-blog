jekyll build

git add .
git commit -m 'update'
git push -u origin master &

cp _site/* ../mad4alcohol.github.com/

cd ../mad4alcohol.github.com
git add .
git commit -m 'update'
git push -u origin master &


